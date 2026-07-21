import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// The app root and the real triage inbox: un-triaged (and due-snoozed) notes with
/// three swipe actions — Keep / Snooze / Discard — light editing on tap, and a
/// discard-undo banner. Keep now **auto-exports to Obsidian** (Slice 7, hybrid): a
/// kept note writes to the vault and vanishes silently. The bottom bar appears only
/// for the *residue* the owner must act on — set up the vault, re-grant access, or
/// retry a stuck note — and is absent when the funnel is clear.
struct TriageRootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    private let vaultStore = UserDefaultsVaultBookmarkStore()
    private var obsidian: ObsidianFolderDestination {
        ObsidianFolderDestination(access: VaultAccess(store: vaultStore))
    }

    // Candidate set (reactive). Kept primitive — string literals mirror
    // NoteStatus.inbox/.snoozed rawValues (asserted in TriageTests). The due-filter
    // runs in the view-model so the clock/calendar stay injectable.
    @Query(filter: #Predicate<Note> { $0.statusRaw == "inbox" || $0.statusRaw == "snoozed" },
           sort: \Note.createdAt, order: .reverse)
    private var candidates: [Note]

    // The export "outbox": kept notes plus any whose last export attempt failed
    // (pending). String literals mirror NoteStatus.kept/.pending rawValues
    // (asserted in NoteStatusRawTests). Drives the batch-export affordance + count.
    @Query(filter: #Predicate<Note> { $0.statusRaw == "kept" || $0.statusRaw == "pending" },
           sort: \Note.createdAt, order: .reverse)
    private var outbox: [Note]

    @State private var vm = TriageViewModel()
    @State private var bannerNoteID: UUID?
    @State private var discardTask: Task<Void, Never>?
    @State private var isExporting = false
    @State private var showingVaultPicker = false
    @State private var refreshToken = 0   // bumped on appear/active to recompute due-ness

    private var outboxState: OutboxState { OutboxSummary.classify(outbox) }

    private var visible: [Note] { vm.visibleNotes(candidates) }
    private var snoozedNotDue: [Note] { vm.snoozedNotDue(candidates) }

    var body: some View {
        List {
            ForEach(visible) { note in
                NavigationLink(value: note) { row(note) }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button { keep(note) } label: { Label("Keep", systemImage: "checkmark") }
                            .tint(.green)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) { discard(note) } label: {
                            Label("Discard", systemImage: "trash")
                        }
                        Button { snooze(note) } label: { Label("Snooze", systemImage: "moon.zzz") }
                            .tint(.orange)
                    }
                    .contextMenu {
                        Button { keep(note) } label: { Label("Keep", systemImage: "checkmark") }
                        Button { snooze(note) } label: { Label("Snooze", systemImage: "moon.zzz") }
                        Button(role: .destructive) { discard(note) } label: {
                            Label("Discard", systemImage: "trash")
                        }
                    }
            }
        }
        .overlay { if visible.isEmpty { emptyState } }
        .navigationTitle("Triage (\(visible.count))")
        .navigationDestination(for: Note.self) { note in
            NoteEditorView(note: note,
                           onKeep: { keep($0) },
                           onSnooze: { snooze($0) },
                           onDiscard: { discard($0) })
        }
        .safeAreaInset(edge: .bottom) {
            // The transient undo banner wins the inset while it's up; otherwise the
            // steady-state export bar shows only when there's residue to act on.
            if bannerNoteID != nil { undoBanner } else { exportBar }
        }
        .fileImporter(isPresented: $showingVaultPicker, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result { setVaultAndDrive(url) }
        }
        .onAppear { refreshToken += 1 }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshToken += 1 }
        }
        .onDisappear { finalizePendingDiscard() }   // navigating to the editor commits a pending discard
    }

    // MARK: - Rows / empty state

    private func row(_ note: Note) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.body).lineLimit(2)
            HStack(spacing: 8) {
                Text(note.createdAt, format: .relative(presentation: .named))
                if note.snoozeCount >= 3 {
                    Text("snoozed \(note.snoozeCount)×")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            ContentUnavailableView("Inbox clear", systemImage: "tray")
            if !snoozedNotDue.isEmpty {
                Text("\(snoozedNotDue.count) will return in a later session")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var undoBanner: some View {
        HStack {
            Text("Note discarded")
            Spacer()
            Button("Undo") { undo() }
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.thinMaterial, in: Capsule())
        .padding(.horizontal)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Note discarded. Undo available.")
    }

    /// The steady-state export residue bar (counts-only). Absent when the funnel is
    /// clear (`.empty`) or notes are silently auto-exporting (`.draining`); present
    /// only when the owner must act — set up the vault, re-grant, or retry.
    @ViewBuilder private var exportBar: some View {
        switch outboxState {
        case .needsSetup(let n):
            exportBarButton("Set up vault to export \(n)", systemImage: "folder.badge.plus") {
                showingVaultPicker = true
            }
        case .stuck(let n, .accessLost):
            exportBarButton("Reconnect your vault · \(n) waiting", systemImage: "arrow.clockwise.icloud") {
                showingVaultPicker = true
            }
        case .stuck(let n, _):
            exportBarButton("Retry \(n)", systemImage: "arrow.clockwise") { driveExport() }
        case .empty, .draining:
            EmptyView()
        }
    }

    private func exportBarButton(_ title: String, systemImage: String,
                                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isExporting)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: - Actions

    /// Keep → auto-export to Obsidian (hybrid). The note writes to the vault and
    /// leaves silently; if no vault is set up yet it lands as `pending(noVaultConfigured)`
    /// and the bottom bar invites a deliberate "Set up vault" — the picker never
    /// interrupts the keep swipe itself.
    private func keep(_ note: Note) {
        vm.keep(note, in: context)
        autoExport()
    }
    private func snooze(_ note: Note) { vm.snooze(note, in: context) }

    /// Fire-and-forget silent export of the freshly-kept notes. Race-safe without
    /// locking: the coordinator marks notes `.writing` and saves before awaiting, and
    /// `autoExportKept` only fetches `.kept`, so overlapping runs can't double-claim.
    private func autoExport() {
        Task { await ExportCoordinator(destination: obsidian).autoExportKept(in: context) }
    }

    /// Deliberate drain (Retry / after vault setup): retries `pending` and drains any
    /// `kept`. Disables the bar while in flight and announces the outcome.
    private func driveExport() {
        guard !isExporting else { return }
        finalizePendingDiscard()
        isExporting = true
        Task {
            let confirmed = await ExportCoordinator(destination: obsidian).exportAll(in: context)
            isExporting = false
            announceExportResult(confirmed: confirmed)
        }
    }

    /// Persist the freshly-picked vault folder, then drain everything waiting on it
    /// (`pending(.noVaultConfigured)` / `.accessLost` + any kept). Same picker serves
    /// first-time setup and re-grant.
    private func setVaultAndDrive(_ url: URL) {
        do {
            try VaultAccess(store: vaultStore).setVault(pickedURL: url)
            driveExport()
        } catch {
            // Couldn't claim access to the picked folder — notes stay pending; the bar
            // remains so the owner can try again. (Device-only failure path.)
        }
    }

    private func announceExportResult(confirmed: Int) {
        if confirmed > 0 {
            let noun = confirmed == 1 ? "note" : "notes"
            AccessibilityNotification.Announcement("Exported \(confirmed) \(noun).").post()
        }
        // Announce the residue (fresh fetch — the @Query hasn't re-rendered yet).
        switch currentOutboxState() {
        case .needsSetup:
            AccessibilityNotification.Announcement("Vault not set up yet.").post()
        case .stuck(let n, .accessLost):
            AccessibilityNotification.Announcement("Couldn't reach your vault. \(n) waiting to reconnect.").post()
        case .stuck(let n, _):
            AccessibilityNotification.Announcement("\(n) still need attention.").post()
        case .empty, .draining:
            break
        }
    }

    /// Classify a *fresh* fetch of the outbox — used right after an export completes,
    /// before the `@Query` has re-rendered, so an announcement reflects the real state.
    private func currentOutboxState() -> OutboxState {
        let kept = NoteStatus.kept.rawValue
        let pending = NoteStatus.pending.rawValue
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate { $0.statusRaw == kept || $0.statusRaw == pending }
        )
        return OutboxSummary.classify((try? context.fetch(descriptor)) ?? [])
    }

    private func discard(_ note: Note) {
        finalizePendingDiscard()          // commit any prior pending immediately
        vm.discard(note)                  // optimistic hide
        let id = note.id
        withAnimation { bannerNoteID = id }
        AccessibilityNotification.Announcement("Note discarded. Undo available.").post()
        discardTask = Task {
            try? await Task.sleep(for: .seconds(4))
            if !Task.isCancelled { commit(id) }
        }
    }

    private func undo() {
        discardTask?.cancel()
        if let id = bannerNoteID { vm.undoDiscard(id) }
        withAnimation { bannerNoteID = nil }
    }

    private func commit(_ id: UUID) {
        vm.commitDiscard(id, in: context)
        if bannerNoteID == id { withAnimation { bannerNoteID = nil } }
    }

    private func finalizePendingDiscard() {
        discardTask?.cancel()
        if let id = bannerNoteID {
            vm.commitDiscard(id, in: context)
            bannerNoteID = nil
        }
    }
}
