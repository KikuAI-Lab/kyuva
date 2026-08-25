import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct ScriptTextTransfer: Transferable {
    let name: String
    let content: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .plainText) { transfer in
            SentTransferredFile(
                try ScriptTextFile.writeExport(
                    name: transfer.name,
                    content: transfer.content
                )
            )
        }
    }
}

extension ScriptTextTransfer {
    static func readImport(from urls: [URL]) throws -> (name: String, content: String) {
        guard let url = urls.first else {
            throw ScriptTextImportError.noFile
        }

        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        if let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
           size > ScriptTextFile.maximumBytes {
            throw ScriptTextImportError.fileTooLarge
        }

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: ScriptTextFile.maximumBytes + 1) ?? Data()
        let content = try ScriptTextFile.decodeImport(data)

        return (url.deletingPathExtension().lastPathComponent, content)
    }
}
