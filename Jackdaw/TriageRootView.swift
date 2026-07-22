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
                    // Swipe actions are invisible to VoiceOver; expose the three verbs
                    // on the Actions rotor too (a11y baseline for the shipped triage screen).
                    .accessibilityActions {
                        Button("Keep") { keep(note) }
                        Button("Snooze") { snooze(note) }
                        Button("Discard", role: .destructive) { discard(note) }
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
            // Re-drive any lingering kept on foreground too (RootView drains at cold
            // launch; this covers a note kept just before a background without a kill).
            if phase == .active { refreshToken += 1; autoExport() }
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
    /// only when the owner must act — set up the vault, re-grant, or retry. The two
    /// recoverable-failure cases carry a "Return to inbox" escape (long-press / the
    /// VoiceOver Actions rotor) so a persistently-failing note can't wedge the funnel.
    @ViewBuilder private var exportBar: some View {
        switch outboxState {
        case .needsSetup(let n):
            // First-time acquisition: a genuine call-to-action → prominent.
            exportBarButton("Set up vault to export \(n)", systemImage: "folder.badge.plus", prominent: true) {
                showingVaultPicker = true
            }
        case .stuck(let n, .accessLost):
            exportBarButton("Reconnect your vault — \(n) waiting",
                            systemImage: "exclamationmark.arrow.circlepath", prominent: false) {
                showingVaultPicker = true
            }
            .stuckEscape(count: n) { returnStuckToInbox() }
        case .stuck(let n, _):
            exportBarButton("Retry \(n)", systemImage: "arrow.clockwise", prominent: false) {
                driveExport()
            }
            .stuckEscape(count: n) { returnStuckToInbox() }
        case .empty, .draining:
            EmptyView()
        }
    }

    /// Recurring failures use a calmer `.bordered`; only the first-time setup CTA is
    /// `.borderedProminent`. The label wraps and floors at a 44 pt target so a
    /// multi-word title stays legible + tappable at large Dynamic Type sizes.
    @ViewBuilder
    private func exportBarButton(_ title: String, systemImage: String, prominent: Bool,
                                 action: @escaping () -> Void) -> some View {
        let label = Label(title, systemImage: systemImage)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 6)
        if prominent {
            Button(action: action) { label }
                .buttonStyle(.borderedProminent)
                .disabled(isExporting)
                .padding(.horizontal).padding(.bottom, 8)
        } else {
            Button(action: action) { label }
                .buttonStyle(.bordered)
                .disabled(isExporting)
                .padding(.horizontal).padding(.bottom, 8)
        }
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

    /// Announce success **and** residue as a *single* utterance — two back-to-back
    /// `.post()`s clobber each other, so the failure half (the important one) got cut.
    private func announceExportResult(confirmed: Int) {
        var parts: [String] = []
        if confirmed > 0 {
            let noun = confirmed == 1 ? "note" : "notes"
            parts.append("Exported \(confirmed) \(noun).")
        }
        // Residue keys off a fresh fetch — the @Query hasn't re-rendered yet.
        switch currentOutboxState() {
        case .needsSetup:                    parts.append("Vault not set up yet.")
        case .stuck(let n, .accessLost):     parts.append("Couldn't reach your vault. \(n) waiting to reconnect.")
        case .stuck(let n, _):               parts.append("\(n) still need attention.")
        case .empty, .draining:              break
        }
        if !parts.isEmpty {
            AccessibilityNotification.Announcement(parts.joined(separator: " ")).post()
        }
    }

    /// Classify a *fresh* fetch of the outbox — used right after an export completes,
    /// before the `@Query` has re-rendered, so an announcement reflects the real state.
    /// Sources the fetch from the coordinator so the kept||pending predicate lives in
    /// one place, not a fourth literal copy.
    private func currentOutboxState() -> OutboxState {
        OutboxSummary.classify(ExportCoordinator(destination: obsidian).outbox(in: context))
    }

    /// Return every stuck (`pending`) note to the un-triaged inbox — the counts-only
    /// escape from a poison note that would otherwise keep the bar lit forever.
    private func returnStuckToInbox() {
        let pending = NoteStatus.pending.rawValue
        let descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.statusRaw == pending })
        for note in (try? context.fetch(descriptor)) ?? [] {
            vm.returnToInbox(note, in: context)
        }
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

private extension View {
    /// The "Return N to inbox" escape on a stuck export bar — reachable by long-press
    /// (context menu) and the VoiceOver Actions rotor. Keeps the surface counts-only:
    /// it acts on the whole stuck set, not a browsable per-note list.
    func stuckEscape(count: Int, action: @escaping () -> Void) -> some View {
        contextMenu {
            Button("Return \(count) to inbox", systemImage: "tray.and.arrow.down", action: action)
        }
        .accessibilityAction(named: Text("Return \(count) to inbox"), action)
    }
}
