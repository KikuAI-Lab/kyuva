import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct ScriptTextTransfer: Transferable {
    let name: String
    let content: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .plainText) { transfer in
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("Kyuva-Share-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            let url = directory.appendingPathComponent(transfer.fileName)
            try Data(transfer.content.utf8).write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }

    private var fileName: String {
        ScriptTextFile.exportName(for: name)
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
