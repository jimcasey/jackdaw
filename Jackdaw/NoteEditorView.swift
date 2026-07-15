import SwiftUI
import SwiftData

/// Light note editing, pushed onto the Triage stack (tap a row). Body editing +
/// time editing this slice; location editing is hooked but deferred to the Location
/// slice. The three triage verbs sit in a bottom bar so you can act right after
/// editing. Deliberately NOT a full editor — plain text only, and no prune (prune
/// is a capture-abandonment rule; a cleared note in Triage just stays).
struct NoteEditorView: View {
    @Bindable var note: Note
    let onKeep: (Note) -> Void
    let onSnooze: (Note) -> Void
    let onDiscard: (Note) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                TextEditor(text: $note.body)
                    .frame(minHeight: 180)
            }
            Section("Context") {
                DatePicker("Captured", selection: $note.createdAt)
                // location row — Location slice
            }
        }
        .navigationTitle("Edit")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { verbBar }
        .onDisappear { try? context.save() }   // durability for the edits
    }

    private var verbBar: some View {
        HStack {
            Button { act { onKeep(note) } } label: {
                Label("Keep", systemImage: "checkmark")
            }
            Spacer()
            Button { act { onSnooze(note) } } label: {
                Label("Snooze", systemImage: "moon.zzz")
            }
            Spacer()
            Button(role: .destructive) { act { onDiscard(note) } } label: {
                Label("Discard", systemImage: "trash")
            }
        }
        .labelStyle(.titleAndIcon)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.bar)
    }

    /// Run a triage verb, then pop back to the list (where any discard banner shows).
    private func act(_ transition: () -> Void) {
        transition()
        dismiss()
    }
}
