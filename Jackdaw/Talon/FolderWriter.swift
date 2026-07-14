import Foundation

/// Pure write+verify at a given (already-accessible) folder URL. Has NO
/// security-scope knowledge, so it is unit-testable against a plain temp
/// directory (Slice 1 spec §6).
///
/// Writes and reads go through `NSFileCoordinator` because another process
/// (Obsidian, or iCloud under the T1 fallback) may touch the folder concurrently
/// (ADR 0001).
struct FolderWriter {
    /// Write `data` as `fileName` into `folder`, then read it back and confirm the
    /// bytes match. Throws `ExportFailure.writeFailed` / `.verifyMismatch`.
    func writeAndVerify(fileName: String, data: Data, into folder: URL) throws {
        let fileURL = folder.appendingPathComponent(fileName)
        try write(data, to: fileURL)
        try verify(data, at: fileURL)
    }

    /// Coordinated atomic write. Split out so `verify` can be tested independently.
    func write(_ data: Data, to fileURL: URL) throws {
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var writeError: Error?
        coordinator.coordinate(writingItemAt: fileURL, options: [], error: &coordinationError) { writeURL in
            do { try data.write(to: writeURL, options: .atomic) } catch { writeError = error }
        }
        if coordinationError != nil || writeError != nil { throw ExportFailure.writeFailed }
    }

    /// Coordinated read-back comparison. Throws `.verifyMismatch` if the bytes on
    /// disk differ from `expected` (or the file can't be read).
    func verify(_ expected: Data, at fileURL: URL) throws {
        let coordinator = NSFileCoordinator()
        var readBack: Data?
        var coordinationError: NSError?
        coordinator.coordinate(readingItemAt: fileURL, options: [], error: &coordinationError) { readURL in
            readBack = try? Data(contentsOf: readURL)
        }
        guard readBack == expected else { throw ExportFailure.verifyMismatch }
    }
}
