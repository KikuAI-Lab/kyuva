import CryptoKit
import Foundation
import Network
import Security

enum LocalRemotePairingError: Error, Equatable, LocalizedError {
    case randomGenerationFailed
    case invalidCode

    var errorDescription: String? {
        switch self {
        case .randomGenerationFailed:
            return "Kyuva could not create a secure pairing code."
        case .invalidCode:
            return "Enter the 16-character pairing code shown on the Mac."
        }
    }
}

enum LocalRemoteSecurity {
    static let serviceType = "_kyuva._tcp"
    static let pairingCodeLength = 16
    static let pairingAlphabet = Array("23456789ABCDEFGHJKLMNPQRSTUVWXYZ")

    private static let keyContext = "kyuva-local-remote-v1:"
    private static let identity = Data("kyuva-v1".utf8)

    static func generatePairingCode() throws -> String {
        var randomBytes = [UInt8](repeating: 0, count: pairingCodeLength)
        guard SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes) == errSecSuccess else {
            throw LocalRemotePairingError.randomGenerationFailed
        }
        return pairingCode(from: randomBytes)
    }

    static func pairingCode(from randomBytes: [UInt8]) -> String {
        String(
            randomBytes.prefix(pairingCodeLength).map {
                pairingAlphabet[Int($0) % pairingAlphabet.count]
            }
        )
    }

    static func normalizedPairingCode(_ input: String) throws -> String {
        let normalized = input
            .uppercased()
            .filter { $0 != " " && $0 != "-" }

        guard
            normalized.count == pairingCodeLength,
            normalized.allSatisfy(pairingAlphabet.contains)
        else {
            throw LocalRemotePairingError.invalidCode
        }
        return normalized
    }

    static func formattedPairingCode(_ code: String) -> String {
        stride(from: 0, to: code.count, by: 4)
            .map { offset in
                let start = code.index(code.startIndex, offsetBy: offset)
                let end = code.index(start, offsetBy: min(4, code.distance(from: start, to: code.endIndex)))
                return String(code[start..<end])
            }
            .joined(separator: "-")
    }

    static func derivedKey(for pairingCode: String) throws -> Data {
        let normalized = try normalizedPairingCode(pairingCode)
        let digest = SHA256.hash(data: Data((keyContext + normalized).utf8))
        return Data(digest)
    }

    static func parameters(pairingCode: String) throws -> NWParameters {
        let tlsOptions = NWProtocolTLS.Options()
        let key = try derivedKey(for: pairingCode)
        let keyData = dispatchData(from: key)
        let identityData = dispatchData(from: identity)

        sec_protocol_options_add_pre_shared_key(
            tlsOptions.securityProtocolOptions,
            keyData as dispatch_data_t,
            identityData as dispatch_data_t
        )

        return NWParameters(tls: tlsOptions, tcp: NWProtocolTCP.Options())
    }

    private static func dispatchData(from data: Data) -> DispatchData {
        data.withUnsafeBytes { buffer in
            DispatchData(bytes: buffer)
        }
    }
}
