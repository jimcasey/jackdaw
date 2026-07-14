---
name: slice-1-spec
description: Slice 1 implementation spec decisions — vault bookmark write+verify harness (proof-point #1 / ADR 0001 gate 2a); the Talon seam seed, storage choice, iOS entitlement reality, and PASS/FAIL topology test.
metadata:
  type: project
---

**Slice 1 spec lives in `docs/slices/slice-1-vault-bookmark.md`** (tech-lead, 2026-07-14). Isolated on-device test harness that retires the project's highest architectural unknown. PASS ratifies topology **T2** (local vault + Obsidian Sync); FAIL flips to **T1** (iCloud), and only if T1 also fails do we consider git (Option D).

**Slice 0 state (given):** walking skeleton reached device via internal TestFlight; pipeline proven. Bundle id `com.jimcodes.Jackdaw`, iOS 26 target, Swift Testing target present. Code: `Jackdaw/JackdawApp.swift` + `Jackdaw/SkeletonView.swift`.

**Key decisions:**
- **Folder picker = SwiftUI `.fileImporter` with `[UTType.folder]`**, NOT `UIDocumentPickerViewController`. Folder selection is not a SwiftUI gap, so no UIKit bridge. Needs `import UniformTypeIdentifiers`.
- **Bookmark storage = `UserDefaults`** (single `Data` blob) for Slice 1 AND recommended to STAY in UserDefaults at Slice 6 — it's app-level config, not per-note record data (SwiftData is for the note collection). NOT Keychain: a bookmark is an OS reference, not a secret. (A git PAT, if Option D ever happened, WOULD be Keychain.)
- **iOS entitlement reality: NOTHING to add to build this.** User-selected folder access needs NO entitlement on iOS (the macOS `com.apple.security.files.user-selected.read-write` family doesn't exist on iOS — sandbox extension is auto-issued by the picker). NO Info.plist usage string for the picker. NO iCloud capability even for the T1 fallback (user-picked iCloud folder is reached via picker+bookmark, not the app's own ubiquity container). Verified vs Apple docs 2026-07-14.

**Call sequence (error-prone iOS bits — full detail in the spec):** pick → `startAccessingSecurityScopedResource()` (guard+defer) → `url.bookmarkData(options: [])` (NOT `.withSecurityScope`, macOS-only) → save to UserDefaults. Resolve: `URL(resolvingBookmarkData:options:[]:relativeTo:nil:bookmarkDataIsStale:&isStale)`; if stale, recreate+resave; guard startAccessing; write+read-back via `NSFileCoordinator` (concurrent access by Obsidian/iCloud). "Verified" in-app = read-back Data == written Data (byte-for-byte).

**Talon seam seed (KEEPER core, reused at Slice 6 — do NOT let Slice 6 rewrite it):** `protocol ExportDestination { func export(fileName:markdown:) throws }`; `VaultBookmarkStore` (+`UserDefaultsVaultBookmarkStore`); `VaultAccess` (resolve+stale+start/stop, on-device-only); `FolderWriter` (pure write+verify at a URL, NO security-scope knowledge → unit-testable off-device); `ObsidianFolderDestination: ExportDestination` composes them. `enum ExportFailure { noVaultConfigured, accessLost, writeFailed, verifyMismatch }` — seeds the Slice 4 failure-reason contract (maps to no-destination-yet / Re-grant / Retry). Separating `FolderWriter` from `VaultAccess` is both design and testability. THROWAWAY = the SwiftUI harness screen (VaultProofView + buttons/status).

**Cold-relaunch test is load-bearing:** must KILL from app switcher (swipe away), not just background — a backgrounded app keeps the resolved URL in memory = false pass. Harness status line computed on launch shows resolve state BEFORE any tap = the persistence proof. Out-of-app confirm = file appears in Obsidian on BOTH iPhone and Mac via Obsidian Sync.

**Swift Testing at this slice:** unit-test `FolderWriter.writeAndVerify` against a plain temp dir (happy path, injected mismatch→verifyMismatch, bad path→writeFailed), `UserDefaultsVaultBookmarkStore` round-trip (suite-named defaults), and any ExportFailure classification helper. CANNOT unit-test (only the on-device protocol proves): picker vends a persistently-writable bookmark, survival across cold relaunch, Obsidian ingestion.

**Open confirmations before implementing:** (1) exact `On My iPhone/Obsidian/<vault>` target; (2) write to vault root vs a subfolder (recommend root for Slice 1); (3) harness placement (recommend swapping JackdawApp to VaultProofView for the slice).

See [[decision-obsidian-write]] (mechanism + gotchas + gates), [[ios-gotchas]] (bookmark/picker facts), [[build-order]] (Slice 1 in context).
