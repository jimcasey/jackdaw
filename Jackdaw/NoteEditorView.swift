import SwiftUI
import SwiftData
import MapKit
import CoreLocation

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
                LocationRow(note: note)
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

/// The captured-location row: a static map thumbnail from the coordinates, a
/// lazily-reverse-geocoded place name, and Clear. "No location" when absent.
/// Geocoding happens at display only (capture stays offline-first).
private struct LocationRow: View {
    @Bindable var note: Note

    var body: some View {
        if note.hasLocation, let lat = note.latitude, let lon = note.longitude {
            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            VStack(alignment: .leading, spacing: 8) {
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: coord, latitudinalMeters: 500, longitudinalMeters: 500))) {
                    Marker("", coordinate: coord)
                }
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .allowsHitTesting(false)
                .accessibilityLabel(accessibilityText)

                if let name = note.placeName {
                    Text(name).font(.subheadline)
                }
                Button("Clear location", role: .destructive, action: clear)
            }
            .task { await geocodeIfNeeded(coord) }
        } else {
            Text("No location").foregroundStyle(.secondary)
        }
    }

    private var accessibilityText: String {
        if let name = note.placeName { return name }
        let lat = note.latitude ?? 0, lon = note.longitude ?? 0
        return "Location: \(lat), \(lon)"
    }

    private func clear() {
        note.latitude = nil
        note.longitude = nil
        note.horizontalAccuracy = nil
        note.placeName = nil
    }

    private func geocodeIfNeeded(_ coord: CLLocationCoordinate2D) async {
        guard note.placeName == nil else { return }
        let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        guard let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location),
              let placemark = placemarks.first else { return }
        note.placeName = [placemark.name, placemark.locality].compactMap { $0 }.first
    }
}
