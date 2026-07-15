import SwiftUI
import SwiftData

/// The app root. This slice it is a **read-only** list so captured notes are
/// visible persisting (Capture shows no list by design). It **grows** into the
/// real triage inbox — swipe actions, editing, retention lifecycle — at the Triage
/// slice; it is not thrown away.
struct TriageRootView: View {
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]

    var body: some View {
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
                ContentUnavailableView("Inbox clear", systemImage: "tray")
            }
        }
        .navigationTitle("Triage (\(notes.count))")
    }
}
