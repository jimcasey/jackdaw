import SwiftUI

/// The Capture screen: launch-to-capture with the keyboard up, a full-bleed
/// editor, and autosave-as-you-type. No Save button — leaving Capture commits the
/// note; the keyboard-toolbar "New note" action banks the current thought and
/// gives a fresh field without leaving (design flow §1, Exit A/B).
struct CaptureView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    @State private var text = ""
    @State private var vm = CaptureViewModel()
    @State private var capturedToken = 0
    @State private var showCaptured = false
    @FocusState private var focused: Bool

    private var isBlank: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("What's on your mind?")
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                        .padding(.horizontal, 5)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .focused($focused)
                    .scrollContentBackground(.hidden)
                    .scrollDismissesKeyboard(.interactively)
            }
            .padding(.horizontal)
            .navigationBarTitleDisplayMode(.inline)
            .overlay(alignment: .top) {
                if showCaptured {
                    Text("Captured")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.thinMaterial, in: Capsule())
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    // Dismiss the keyboard so the floating tab bar is reachable —
                    // Return inserts a newline in a TextEditor, so this is the only
                    // way out of Capture toward Triage. The draft is already saved.
                    Button("Done", systemImage: "keyboard.chevron.compact.down") {
                        focused = false
                    }
                    Spacer()
                    Button("New note", systemImage: "plus.circle.fill") {
                        captureAnother()
                    }
                    .disabled(isBlank)
                }
            }
            .sensoryFeedback(.success, trigger: capturedToken)
            .task { focused = true }
            .onChange(of: text) { _, newValue in
                vm.edit(newValue, in: context)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { vm.finishEditing(in: context) }
            }
            .onDisappear {
                vm.finishEditing(in: context)
                text = ""
            }
        }
    }

    /// Exit B — bank the current (non-empty) note and start a fresh one without
    /// leaving Capture. The note is already saved; this is a delimiter, not a save.
    private func captureAnother() {
        vm.finishEditing(in: context)   // commit current row, detach draft
        text = ""                        // fresh field; next keystroke = new row
        focused = true                   // keep the keyboard up
        capturedToken += 1               // fires the success haptic
        flashCaptured()
    }

    private func flashCaptured() {
        let token = capturedToken
        withAnimation { showCaptured = true }
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            if token == capturedToken {
                withAnimation { showCaptured = false }
            }
        }
    }
}
