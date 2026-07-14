import Foundation

/// The Talon seed: composes `VaultAccess` (security scope) with `FolderWriter`
/// (write+verify) behind the `ExportDestination` seam. Slice 6 reuses this
/// verbatim; only the harness UI around it is throwaway.
struct ObsidianFolderDestination: ExportDestination {
    let access: VaultAccess
    let writer = FolderWriter()

    func export(fileName: String, markdown: String) throws {
        try access.withVaultURL { url in
            try writer.writeAndVerify(fileName: fileName,
                                      data: Data(markdown.utf8),
                                      into: url)
        }
    }
}
