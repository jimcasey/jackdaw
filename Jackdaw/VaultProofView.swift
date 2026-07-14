import SwiftUI
import UniformTypeIdentifiers

/// Slice 1 test harness (THROWAWAY — deleted/replaced at Slice 6).
///
/// Its only job is to make the keeper core observable on-device: pick a folder,
/// write a verified note, and — critically — show on launch whether a saved
/// bookmark still resolves. After a cold relaunch you read the status line
/// *before tapping anything*; that is the persistence proof (see Slice 1 spec §5).
struct VaultProofView: View {
    private let store: VaultBookmarkStore = UserDefaultsVaultBookmarkStore()
    private var access: VaultAccess { VaultAccess(store: store) }
    private var destination: ObsidianFolderDestination { ObsidianFolderDestination(access: access) }

    @State private var statusLine = "…"
    @State private var statusOK: Bool?
    @State private var resolvedDetail = ""
    @State private var resultLine = ""
    @State private var showingPicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Vault (resolved on launch)") {
                    Label(statusLine, systemImage: statusSymbol)
                        .foregroundStyle(statusColor)
                    if !resolvedDetail.isEmpty {
                        Text(resolvedDetail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                Section("Actions") {
                    Button("Pick vault folder") { showingPicker = true }
                    Button("Write test note") { writeTestNote() }
                    Button("Clear vault", role: .destructive) { clearVault() }
                }

                if !resultLine.isEmpty {
                    Section("Last write result") {
                        Text(resultLine).font(.callout)
                    }
                }
            }
            .navigationTitle("Slice 1 · Vault Proof")
            .onAppear(perform: refreshStatus)
            .fileImporter(isPresented: $showingPicker, allowedContentTypes: [.folder]) { result in
                switch result {
                case .success(let url): handlePicked(url)
                case .failure(let error): resultLine = "Picker error: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Status presentation

    private var statusSymbol: String {
        switch statusOK {
        case .some(true): "checkmark.seal.fill"
        case .some(false): "xmark.seal.fill"
        case .none: "questionmark.circle"
        }
    }

    private var statusColor: Color {
        switch statusOK {
        case .some(true): .green
        case .some(false): .red
        case .none: .secondary
        }
    }

    // MARK: - Actions

    private func refreshStatus() {
        switch access.status() {
        case .noVault:
            statusLine = "No vault set"; statusOK = nil; resolvedDetail = ""
        case let .resolved(name, path):
            statusLine = "Vault set: \(name) — bookmark resolves"; statusOK = true; resolvedDetail = path
        case let .resolvedStaleRecreated(name, path):
            statusLine = "Vault set: \(name) — resolved, was STALE (recreated)"; statusOK = true; resolvedDetail = path
        case let .resolveFailed(err):
            statusLine = "Vault set but resolve FAILED"; statusOK = false; resolvedDetail = err
        }
    }

    private func handlePicked(_ url: URL) {
        do {
            try access.setVault(pickedURL: url)
            resultLine = "Vault folder saved."
        } catch {
            resultLine = "Failed to save vault: \(describe(error))"
        }
        refreshStatus()
    }

    private func writeTestNote() {
        let name = "jackdaw-slice1-\(Self.fileTimestamp()).md"
        do {
            try destination.export(fileName: name, markdown: Self.testMarkdown())
            resultLine = "Wrote \(name)\nVerify: PASS ✅"
        } catch {
            resultLine = "Wrote \(name)\nVerify: FAIL ❌ (\(describe(error)))"
        }
    }

    private func clearVault() {
        store.clear()
        resultLine = "Vault cleared."
        refreshStatus()
    }

    // MARK: - Helpers

    private func describe(_ error: Error) -> String {
        if let failure = error as? ExportFailure {
            switch failure {
            case .noVaultConfigured: return "noVaultConfigured"
            case .accessLost: return "accessLost"
            case .writeFailed: return "writeFailed"
            case .verifyMismatch: return "verifyMismatch"
            }
        }
        return String(describing: error)
    }

    private static func fileTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: Date())
    }

    private static func testMarkdown() -> String {
        let iso = ISO8601DateFormatter().string(from: Date())
        return """
        ---
        source: jackdaw-slice1
        captured: \(iso)
        ---

        Jackdaw Slice 1 proof-point test note.
        Written at \(iso).
        """
    }
}

#Preview {
    VaultProofView()
}
