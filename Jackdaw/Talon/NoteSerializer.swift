import Foundation

/// A plain, SwiftData-free snapshot of the note fields the serializer needs.
///
/// Decoupling from the `@Model` keeps `NoteSerializer` a pure value transform —
/// trivially unit-testable off-device with hand-built snapshots, no in-memory
/// `ModelContainer` required — and keeps this layer free of the SwiftData import,
/// the same discipline `CaptureService`/`FolderWriter` follow.
struct NoteSnapshot: Equatable {
    let id: UUID
    let body: String
    let createdAt: Date
    let latitude: Double?
    let longitude: Double?
    let horizontalAccuracy: Double?
    let placeName: String?

    init(id: UUID,
         body: String,
         createdAt: Date,
         latitude: Double? = nil,
         longitude: Double? = nil,
         horizontalAccuracy: Double? = nil,
         placeName: String? = nil) {
        self.id = id
        self.body = body
        self.createdAt = createdAt
        self.latitude = latitude
        self.longitude = longitude
        self.horizontalAccuracy = horizontalAccuracy
        self.placeName = placeName
    }

    init(_ note: Note) {
        self.init(id: note.id,
                  body: note.body,
                  createdAt: note.createdAt,
                  latitude: note.latitude,
                  longitude: note.longitude,
                  horizontalAccuracy: note.horizontalAccuracy,
                  placeName: note.placeName)
    }
}

/// Turns a note into a `SerializedNote` — a filename plus a markdown body with YAML
/// frontmatter (timestamp + precise GPS). **Reused verbatim by the Obsidian
/// adapter** (Slice 6): the on-disk file format is destination-independent.
///
/// Everything here is deterministic — fixed `en_US_POSIX`/UTC formatters, no
/// `Date()`, no locale-sensitive number formatting — so the output is stable across
/// CI machines and directly assertable in tests.
struct NoteSerializer {
    func serialize(_ note: NoteSnapshot) -> SerializedNote {
        SerializedNote(id: note.id,
                       fileName: fileName(for: note),
                       markdown: markdown(for: note))
    }

    /// `yyyy-MM-dd-HHmmss-<8 hex>.md` in UTC. The timestamp makes files sort and
    /// read naturally in Obsidian; the short id suffix guarantees uniqueness so a
    /// batch with two notes in the same second can't overwrite each other (the
    /// atomic write would otherwise clobber the first).
    func fileName(for note: NoteSnapshot) -> String {
        let stamp = Self.fileStamp.string(from: note.createdAt)
        let suffix = note.id.uuidString.replacingOccurrences(of: "-", with: "").prefix(8).lowercased()
        return "\(stamp)-\(suffix).md"
    }

    /// Frontmatter block, a blank line, then the raw body.
    func markdown(for note: NoteSnapshot) -> String {
        frontmatter(for: note) + "\n" + note.body + "\n"
    }

    // MARK: - Frontmatter

    private func frontmatter(for note: NoteSnapshot) -> String {
        var lines = ["---", "created: \(Self.iso.string(from: note.createdAt))"]
        // Location is optional context: omit the keys entirely when absent, rather
        // than writing nulls, so a timestamp-only note stays clean.
        if let lat = note.latitude, let lon = note.longitude {
            lines.append("latitude: \(Self.number(lat))")
            lines.append("longitude: \(Self.number(lon))")
            if let accuracy = note.horizontalAccuracy {
                lines.append("accuracy_m: \(Self.number(accuracy))")
            }
        }
        if let place = note.placeName, !place.isEmpty {
            lines.append("place: \(Self.yamlQuoted(place))")
        }
        lines.append("---")
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Deterministic formatters

    /// ISO-8601 in UTC, e.g. `2026-07-21T14:30:00Z`.
    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private static let fileStamp: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd-HHmmss"
        return f
    }()

    /// Fixed 6-decimal formatting via `String(format:)`, which is locale-independent
    /// for `%f` — so a device set to a comma-decimal locale still emits `-122.009000`,
    /// not `-122,009000` (which would corrupt the YAML).
    private static func number(_ value: Double) -> String {
        String(format: "%.6f", value)
    }

    /// Always double-quote string values and escape `\` and `"`, so a place name
    /// containing YAML-significant characters (`:`, `#`, a leading `-`) can't break
    /// the frontmatter.
    private static func yamlQuoted(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
