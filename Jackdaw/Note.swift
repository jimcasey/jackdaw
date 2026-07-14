import Foundation
import SwiftData

/// A captured note. Slice 2 keeps this minimal — `id`, `body`, `createdAt`.
///
/// Location (Slice 3) and the retention lifecycle `status` (Slice 4) are added
/// additively at their own slices; SwiftData performs automatic lightweight
/// migration for optional/defaulted properties, and pre-release we can simply
/// reset the local store. No `SchemaMigrationPlan` until there is real data worth
/// preserving. (See `docs/slices/slice-2-capture-swiftdata.md` §2.)
///
/// `@Model` must be a `final class`: SwiftData tracks objects by reference
/// identity to observe mutations and persist them. The macro rewrites the class at
/// compile time to add the persistence mapping.
@Model
final class Note {
    /// Stable identity independent of SwiftData's `PersistentIdentifier`. We hold
    /// onto this because a note later becomes an export filename (Slice 6).
    var id: UUID
    var body: String
    var createdAt: Date

    init(id: UUID = UUID(), body: String, createdAt: Date = .now) {
        self.id = id
        self.body = body
        self.createdAt = createdAt
    }
}
