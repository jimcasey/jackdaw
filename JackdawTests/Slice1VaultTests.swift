import Testing
import Foundation
@testable import Jackdaw

/// Off-device tests for the reusable Talon core. These cover the *mechanics*
/// (write, verify, bookmark round-trip); the platform risk (a persistently
/// writable picker bookmark surviving a cold launch, Obsidian ingestion) can only
/// be retired by the on-device protocol in the Slice 1 spec §5.
struct FolderWriterTests {
    let writer = FolderWriter()

    private func makeTempFolder() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("jackdaw-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test func writeAndVerify_happyPath_writesBytesThatReadBack() throws {
        let folder = try makeTempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        let payload = Data("hello jackdaw \(UUID())".utf8)
        try writer.writeAndVerify(fileName: "note.md", data: payload, into: folder)

        let onDisk = try Data(contentsOf: folder.appendingPathComponent("note.md"))
        #expect(onDisk == payload)
    }

    @Test func verify_whenBytesDiffer_throwsVerifyMismatch() throws {
        let folder = try makeTempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        let fileURL = folder.appendingPathComponent("note.md")
        try writer.write(Data("actual contents".utf8), to: fileURL)

        #expect(throws: ExportFailure.verifyMismatch) {
            try writer.verify(Data("different contents".utf8), at: fileURL)
        }
    }

    @Test func write_toNonexistentParent_throwsWriteFailed() {
        let bogus = URL(fileURLWithPath: "/no-such-dir-\(UUID().uuidString)/note.md")
        #expect(throws: ExportFailure.writeFailed) {
            try writer.write(Data("x".utf8), to: bogus)
        }
    }
}

struct VaultBookmarkStoreTests {
    private func makeStore() -> UserDefaultsVaultBookmarkStore {
        let defaults = UserDefaults(suiteName: "jackdaw-tests-\(UUID().uuidString)")!
        return UserDefaultsVaultBookmarkStore(defaults: defaults)
    }

    @Test func saveThenLoad_returnsEqualData() {
        let store = makeStore()
        let blob = Data("bookmark-blob".utf8)
        store.save(blob)
        #expect(store.load() == blob)
    }

    @Test func clear_removesBookmark() {
        let store = makeStore()
        store.save(Data("blob".utf8))
        store.clear()
        #expect(store.load() == nil)
    }

    @Test func load_whenNothingSaved_returnsNil() {
        #expect(makeStore().load() == nil)
    }
}
