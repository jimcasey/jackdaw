import SwiftUI

/// The Capture sheet (ADR 0004): a modal presented over the Triage root, with its
/// own keyboard and dismissal. Autosave-as-you-type — no explicit Save. Dismissing
/// the sheet commits the note; the keyboard-toolbar "New note" action banks the
/// current thought and gives a fresh field without leaving.
struct CaptureView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var vm = CaptureViewModel(service: CaptureService(location: CoreLocationProvider.shared))
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
            }
            .padding(.horizontal)
            .navigationTitle("Capture")
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
                ToolbarItem(placement: .confirmationAction) {
                    // Commit + close. The note is already saved; this just leaves.
                    Button("Done") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("New note", systemImage: "plus.circle.fill") {
                        captureAnother()
                    }
                    .disabled(isBlank)
                }
            }
            .sensoryFeedback(.success, trigger: capturedToken)
            .task {
                focused = true
                CoreLocationProvider.shared.prewarm()   // warm GPS if already authorized
            }
            .onChange(of: text) { _, newValue in
                vm.edit(newValue, in: context)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { vm.finishEditing(in: context) }
            }
            .onDisappear {
                // Sheet dismissal is the single, deterministic "leaving" event.
                vm.finishEditing(in: context)
                CoreLocationProvider.shared.stopPrewarm()
            }
        }
        .presentationDragIndicator(.visible)
    }

    /// Bank the current (non-empty) note and start a fresh one without leaving the
    /// sheet. The note is already saved; this is a delimiter, not a save.
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
