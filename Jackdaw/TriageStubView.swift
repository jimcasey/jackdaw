import SwiftUI
import SwiftData

/// THROWAWAY — Slice 2 persistence probe only. Replaced wholesale by the real
/// triage inbox at Slice 4 (swipe actions, editing, retention lifecycle).
///
/// Its sole purpose this slice: the Capture screen shows no list by design, so we
/// need somewhere to *see* that autosaved notes actually persisted (and survive a
/// relaunch). It exercises the reads-in-view `@Query` policy in a low-stakes place.
struct TriageStubView: View {
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]

    var body: some View {
        NavigationStack {
            List(notes) { note in
                VStack(alignment: .leading, spacing: 4) {
                    Text(note.body).lineLimit(2)
                    Text(note.createdAt, format: .relative(presentation: .named))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .overlay {
                if notes.isEmpty {
                    ContentUnavailableView("No notes yet", systemImage: "tray")
                }
            }
            .navigationTitle("Triage (\(notes.count))")
        }
    }
}
