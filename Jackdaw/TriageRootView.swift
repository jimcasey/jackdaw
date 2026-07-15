import SwiftUI
import SwiftData

/// The app root and the real triage inbox: a batch of un-triaged (and due-snoozed)
/// notes with three swipe actions — Keep / Snooze / Discard — light editing on tap,
/// and a discard-undo banner. Grows the earlier read-only list.
struct TriageRootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    // Candidate set (reactive). Kept primitive — string literals mirror
    // NoteStatus.inbox/.snoozed rawValues (asserted in TriageTests). The due-filter
    // runs in the view-model so the clock/calendar stay injectable.
    @Query(filter: #Predicate<Note> { $0.statusRaw == "inbox" || $0.statusRaw == "snoozed" },
           sort: \Note.createdAt, order: .reverse)
    private var candidates: [Note]

    @State private var vm = TriageViewModel()
    @State private var bannerNoteID: UUID?
    @State private var discardTask: Task<Void, Never>?
    @State private var refreshToken = 0   // bumped on appear/active to recompute due-ness

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
            if bannerNoteID != nil { undoBanner }
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

    // MARK: - Actions

    private func keep(_ note: Note) { vm.keep(note, in: context) }
    private func snooze(_ note: Note) { vm.snooze(note, in: context) }

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
