# Slice 1 — Vault bookmark write+verify (proof-point #1)

> **Status:** Implementation spec, ready to build. **Date:** 2026-07-14.
> **Owner of spec:** tech-lead. **Implements:** ADR 0001 verification gate 2(a).
> **Prereq met:** Slice 0 green — walking skeleton reached device via internal
> TestFlight. Bundle id `com.jimcodes.Jackdaw`, iOS 26 target, Swift Testing
> target present. Current code: `Jackdaw/JackdawApp.swift`,
> `Jackdaw/SkeletonView.swift`.
>
> **What this slice decides:** the app's export topology. A **PASS ratifies T2**
> (local `On My iPhone/Obsidian/<vault>` + Obsidian Sync — the recommended
> topology in ADR 0001). A **FAIL flips to T1** (iCloud `Obsidian/<vault>`). This
> is the single highest architectural unknown in the project; nothing downstream
> should be built until it is retired.

---

## 1. Scope & non-scope

**In scope — a deliberately isolated test harness:**
- Pick a folder via the system picker; persist a **security-scoped bookmark**.
- On a later **cold launch**, resolve that bookmark and prove it still grants
  write access.
- Write a `.md` file into the folder and **read it back to verify** the bytes.
- A minimal SwiftUI harness UI that makes the bookmark's *persistence across cold
  launch* directly observable.

**Explicitly NOT in scope (do not build yet):**
- No capture, no triage, no note model, no **SwiftData** (that arrives at Slice 2,
  ADR 0003). No serializer, no retention state machine, no batch export.
- No YAML-frontmatter *feature* — the test file includes a tiny frontmatter block
  only as a free preview of the real format; it is not the frontmatter subsystem.
- No first-run onboarding, no re-grant recovery UX (that is Slice 6, and it is
  lazy — ADR-reconciled build order). Here the "pick folder" button is a raw
  harness control, not a designed flow.

**Bookmark storage for this slice: `UserDefaults`.** The bookmark is a single
`Data` blob. `UserDefaults` is the right home for it: it is app-level *config*
(which vault), not per-note *record* data.

**Recommendation for Slice 2+ (stated now so it is a decision, not a drift):**
**keep the bookmark in `UserDefaults`, do not migrate it into SwiftData.**
Reasoning for the owner (new to iOS):
- SwiftData (ADR 0003) is for the growing *collection of note records* with a
  lifecycle. The vault bookmark is a **singleton app setting** — exactly what
  `UserDefaults` is for. Putting it in the note store would be mixing config into
  the data model for no benefit.
- It is **not a credential** (a bookmark is an opaque OS reference, not a secret),
  so the Keychain is unnecessary ceremony. If we ever stored an actual token (git
  PAT, Option D fallback), *that* would go in the Keychain — the bookmark does not.

---

## 2. The exact API flow (with iOS reasoning)

### Folder picker: use SwiftUI `.fileImporter`, not `UIDocumentPickerViewController`

**Decision: `.fileImporter(isPresented:allowedContentTypes:onCompletion:)` with
`[UTType.folder]`.** Justification for iOS 26:
- `.fileImporter` is the native SwiftUI wrapper over the same system document
  picker; it presents the Files UI and returns a **security-scoped URL** — the
  identical capability `UIDocumentPickerViewController` gives, with no
  `UIViewControllerRepresentable` bridging code to write and maintain.
- Our stack default is SwiftUI-first, dropping to UIKit only where SwiftUI has a
  *real gap*. Folder selection is **not** a gap — `.fileImporter` supports
  `[.folder]` fully. So there is no reason to reach for the UIKit controller here.
  ([SerialCoder — fileImporter](https://serialcoder.dev/text-tutorials/swiftui/the-file-importer-in-swiftui/),
  [Apple — Providing access to directories](https://developer.apple.com/documentation/uikit/providing-access-to-directories))
- Requires `import UniformTypeIdentifiers` for `UTType.folder`.

### The call sequence (this is the error-prone part — follow it exactly)

The ADR-recorded gotchas (do not re-derive them; they are in
`docs/adr/0001-obsidian-write-mechanism.md` §Consequences and the tech-lead
`ios-gotchas` memory) are applied below at the specific call sites:

**A. On folder pick (create + persist bookmark):**
1. `.fileImporter` completes with `Result<URL, Error>`; on `.success(url)` you
   hold the folder URL.
2. `guard url.startAccessingSecurityScopedResource() else { ...fail... }` — the
   picker URL is security-scoped; you must claim access before using it. Pair with
   a `defer { url.stopAccessingSecurityScopedResource() }`.
3. Create the bookmark **while holding access**:
   `let data = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)`
   — **`options: []`** (default). **Do NOT pass `.withSecurityScope`** — that
   option is **macOS-only** and is a real trap on iOS (ADR 0001 gotcha). Creating
   the bookmark inside the start/stop access window is what makes it carry the
   scope on iOS.
4. Persist `data` to `UserDefaults` via the `VaultBookmarkStore` (see §4).

**B. On resolve (every cold launch, and before every write):**
1. `guard let data = store.load() else { ...no vault set... }`
2. Resolve:
   ```
   var isStale = false
   let url = try URL(resolvingBookmarkData: data,
                     options: [],            // NOT .withSecurityScope (macOS-only)
                     relativeTo: nil,
                     bookmarkDataIsStale: &isStale)
   ```
   A `throw` here after a cold launch is a **hard FAIL** (bookmark did not
   survive) — see §5.
3. `guard url.startAccessingSecurityScopedResource() else { throw .accessLost }`
   then `defer { url.stopAccessingSecurityScopedResource() }`.
4. **If `isStale == true`:** re-create the bookmark from the freshly-resolved
   (and now-accessed) `url` via `url.bookmarkData(options: [], ...)` and re-save
   it. One-shot staleness (e.g. after an OS update) is normal and recoverable; a
   bookmark that is stale *on every launch and never sticks* is a FAIL (§5).

**C. Write + verify (through `NSFileCoordinator`):**
Another process (Obsidian, or iCloud under T1) may touch the folder concurrently,
so the write goes through a file coordinator (ADR 0001 gotcha):
```
let fileURL = url.appendingPathComponent(fileName)          // unique, timestamped
let payload = Data(markdown.utf8)
let coordinator = NSFileCoordinator()
var coordErr: NSError?
var innerErr: Error?
coordinator.coordinate(writingItemAt: fileURL, options: [], error: &coordErr) { writeURL in
    do { try payload.write(to: writeURL, options: .atomic) } catch { innerErr = error }
}
// throw on coordErr or innerErr  -> maps to .writeFailed
// then read back (also coordinated):
var readBack: Data?
coordinator.coordinate(readingItemAt: fileURL, options: [], error: &coordErr) { readURL in
    readBack = try? Data(contentsOf: readURL)
}
guard readBack == payload else { throw .verifyMismatch }     // byte-for-byte
```
**"Verified" in-app = `readBack == payload` (byte-for-byte, which also implies
size match).** The out-of-app half of verification (Obsidian ingests it) is the
manual protocol in §5.

---

## 3. Entitlements / Info.plist reality

**Good news for the owner: on iOS there is nothing to add to build this.**

- **No entitlement is required** for user-selected folder access on iOS. The
  macOS App Sandbox needs `com.apple.security.files.user-selected.read-write`;
  that entitlement family **does not exist on iOS** — the system issues a sandbox
  extension automatically when the user picks the folder in the document picker.
  Do not go hunting for a capability to toggle; there isn't one.
  ([Apple — Accessing files from the macOS App Sandbox](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox),
  [Apple — Providing access to directories](https://developer.apple.com/documentation/uikit/providing-access-to-directories))
- **No Info.plist usage string is required** for the document picker (contrast
  location, which *does* need `NSLocation…UsageDescription` — that lands at
  Slice 3, not here). The picker is a user-initiated system UI; no purpose string.
- **You do NOT need the iCloud capability**, even for the T1 fallback. The iCloud
  container entitlement is for your app's *own* ubiquity container. Reaching a
  user-picked iCloud Drive folder happens through the **picker + bookmark**, not
  through your own container — so T1 needs no capability either. (Flagging this so
  a FAIL→T1 pivot doesn't send you adding iCloud capabilities you don't need.)
- **Not needed here:** `UIFileSharingEnabled` / `LSSupportsOpeningDocumentsInPlace`
  expose *your app's* Documents folder to Files — irrelevant to reading someone
  else's folder. Leave them off.

**Net: no target changes are required before this slice builds.** If the build
complains, it is a code issue, not a missing entitlement.

---

## 4. Structure: reusable core vs. throwaway harness

This slice is the **seed of the `Talon` / `ExportDestination` subsystem** (ADR
0001). Build the boundary now so Slice 6 *reuses* it instead of rewriting it. Keep
the security-scope acquisition **separate** from the write+verify — that
separation is both good design and what makes the write+verify unit-testable
off-device (§6).

**KEEPER core (carries forward to Slice 6):**

```
// The seam. Slice 6's serializer + retention state machine sit ABOVE this.
protocol ExportDestination {
    func export(fileName: String, markdown: String) throws
}

// Persists the single vault bookmark blob. Stays UserDefaults-backed at Slice 6.
protocol VaultBookmarkStore {
    func save(_ bookmark: Data)
    func load() -> Data?
    func clear()
}
struct UserDefaultsVaultBookmarkStore: VaultBookmarkStore { /* key: "vaultBookmark" */ }

// Resolves the bookmark to an accessed URL; handles staleness + start/stop.
// This is the on-device-only, security-scope layer.
struct VaultAccess {
    let store: VaultBookmarkStore
    // Returns a URL with access already started; caller stops it (or use a
    // withAccess { url in ... } closure form that stops on exit — preferred).
    func withVaultURL<T>(_ body: (URL) throws -> T) throws -> T
}

// Pure write+verify at a given folder URL. NO security-scope knowledge ->
// unit-testable against a plain temp directory.
struct FolderWriter {
    func writeAndVerify(fileName: String, data: Data, into folder: URL) throws
}

// Composes VaultAccess + FolderWriter behind the seam. The Talon seed.
struct ObsidianFolderDestination: ExportDestination {
    let access: VaultAccess
    let writer = FolderWriter()
    func export(fileName: String, markdown: String) throws {
        try access.withVaultURL { url in
            try writer.writeAndVerify(fileName: fileName,
                                      data: Data(markdown.utf8), into: url)
        }
    }
}

// Failure taxonomy — seeds the Slice 4 seam contract's failure-reason enum.
enum ExportFailure: Error {
    case noVaultConfigured   // -> Slice 4 "no-destination-yet"
    case accessLost          // stale/unresolvable bookmark, startAccessing false -> "Re-grant"
    case writeFailed         // coordinator/write threw -> "Retry"
    case verifyMismatch      // read-back != written -> "Retry" (and investigate)
}
```

> Note the `ExportFailure` cases map 1:1 onto the **failure-reason contract** the
> design-lead surfaced for Slice 4 (offline / access-lost / write-error /
> no-destination-yet). Slice 1 seeds that enum so Slice 4/6 don't invent a second
> one. (`offline` is not reachable in this local-folder slice; it appears when
> propagation/network enters the picture — the enum leaves room for it.)

**THROWAWAY harness (delete/replace at Slice 6):**
- The SwiftUI test screen and its view model: the "Pick vault folder" button,
  "Write test note" button, status/result labels. This is scaffolding to *observe*
  the keeper core on-device. Wire it as a new `VaultProofView` and point
  `JackdawApp` at it (keep `SkeletonView` around or swap it — either is fine, it's
  the harness).

**Harness UI requirements (so the cold-launch test is observable):**
- **Vault section:** a status line that, computed **on `.onAppear`/launch**, shows
  one of: `No vault set` / `Vault set: <folder name> — bookmark resolves ✓` /
  `Vault set but resolve FAILED ✗` / `Resolved but was STALE (recreated)`. Plus
  the resolved path. This line is the **persistence proof** — after a cold
  relaunch the owner reads it *before tapping anything*.
- **"Pick vault folder"** button → `.fileImporter`.
- **"Write test note"** button → runs `export(...)`; result line shows the written
  filename, `Verify: PASS`/`FAIL`, and on failure the `ExportFailure` case.
- **"Clear vault"** button → `store.clear()` (reset between test runs).

---

## 5. On-device PASS / FAIL protocol (the crucial part)

Run this **on the owner's physical iPhone, via TestFlight** — not the simulator.
The simulator does not reproduce the real document picker grant semantics, the
Obsidian container, or Obsidian Sync, so a simulator "pass" proves nothing.

**Setup:** the Obsidian vault is at `On My iPhone → Obsidian → <vault>` with
Obsidian Sync running to the Mac (T2). (This is already confirmed to ingest
hand-dropped files — ADR 0001 gate 2b. This slice proves the *app* can do it.)

**Step-by-step:**
1. Install the Slice-1 build via TestFlight. Launch. Status should read
   **`No vault set`**.
2. Tap **Pick vault folder** → in the picker, navigate to
   `On My iPhone → Obsidian → <vault>` and select that folder. Status should flip
   to **`Vault set: <vault> — bookmark resolves ✓`**.
3. Tap **Write test note**. Result should read **`Verify: PASS`** with a filename
   like `jackdaw-slice1-2026-07-14T…​.md`. *(This proves same-session write; it
   does NOT yet prove persistence.)*
4. **Force a COLD relaunch — this is the load-bearing step.** Swipe up to the app
   switcher and **swipe the Jackdaw card away to kill it** (do **not** just press
   Home / background it — a backgrounded app keeps its resolved URL alive in
   memory and would give a false pass). Then reopen Jackdaw from the Home screen.
5. On this fresh launch, **before tapping anything**, read the status line. A PASS
   shows **`Vault set: <vault> — bookmark resolves ✓`** (or `…— STALE (recreated)`,
   which is still a pass). This proves the bookmark **persisted and re-resolved
   across a cold launch**.
6. Tap **Write test note** again → expect **`Verify: PASS`** with a new filename.
7. **Out-of-app confirmation:** open **Obsidian on the iPhone** — both test files
   should be present in the vault. Then open **Obsidian on the Mac** — after
   Obsidian Sync settles, the same files should appear there. Open one and confirm
   the body/frontmatter is intact.

**PASS (ratifies T2) = all of:** step 5 shows the bookmark resolving after a cold
kill, step 6 write+read-back verifies in-app, **and** step 7 shows the files in
Obsidian on **both** devices with intact content.

**FAIL modes (any one is a fail):**
- **Picker won't vend a persistently writable bookmark:** `startAccessing…`
  returns `false`, or the write throws a permissions error → `.accessLost` /
  `.writeFailed`.
- **Resolve fails after cold launch:** step 5 shows `resolve FAILED ✗`
  (`URL(resolvingBookmarkData:)` threw) — the bookmark did not survive.
- **Stale loop:** step 5 shows `STALE (recreated)` on *every* cold launch and
  never settles to a clean resolve — recreation isn't sticking.
- **Write throws:** `.writeFailed` from the coordinator/write.
- **Read-back mismatch:** `.verifyMismatch` (in-app bytes differ).
- **Obsidian ignores the file:** in-app `Verify: PASS` but the file never appears
  in Obsidian on the iPhone (e.g. written to the wrong subpath, or Obsidian
  ignore rules) — the funnel's endpoint isn't actually reached.

**On ANY fail:** re-run this entire protocol **against the iCloud
`Obsidian/<vault>` folder (T1)** — move/point the vault there, re-pick, and repeat
steps 1–7. Only if **T1 also fails** do we escalate to the git fallback (Option D,
ADR 0001) — and per the ADR, that path first requires confirming a currently
maintained, SPM-installable libgit2 wrapper. **Do not jump to git on a single T2
failure.**

---

## 6. Test-target note (Swift Testing)

The Swift Testing target exists; use it for the parts that **don't** need a real
picker-vended, security-scoped URL. The design in §4 (separating `FolderWriter`
from `VaultAccess`) is what makes this possible.

**Worth a unit test (off-device, fast, deterministic):**
- **`FolderWriter.writeAndVerify` against a plain temp directory**
  (`FileManager.default.temporaryDirectory`, no security scope): (a) happy path
  writes the file and the read-back matches; (b) inject a mismatch (write, then
  mutate the file, then verify) → expect `.verifyMismatch`; (c) write into a
  non-writable/nonexistent path → expect `.writeFailed`. This exercises the
  coordinator + verify logic — the reusable core — without a device.
- **`UserDefaultsVaultBookmarkStore` round-trip** using a test suite
  `UserDefaults(suiteName:)`: `save` → `load` returns equal `Data`; `clear` →
  `load` returns `nil`.
- **`ExportFailure` mapping** if you add a helper that classifies thrown
  `NSError`s into cases — assert the classification.

**Cannot be unit-tested — only the §5 on-device protocol proves it:**
- That the **document picker vends a persistently writable** security-scoped
  bookmark into Obsidian's container.
- That the bookmark **survives a cold relaunch** and re-resolves.
- That **Obsidian + Obsidian Sync ingest** the app-written file on both devices.

These three are the entire reason Slice 1 exists; no test double can stand in for
them. The unit tests protect the *mechanics*; the manual protocol retires the
*platform risk*.

---

## Open confirmations before implementation

1. **Vault folder name/path** the owner will pick in step 2 (the exact
   `On My iPhone/Obsidian/<vault>` target).
2. **Where the write lands:** vault **root**, or a subfolder (e.g. `inbox/`)? Root
   is simplest for the proof; a subfolder is closer to the real inbox. Recommend
   **root for Slice 1** (fewer variables) unless the owner wants the subfolder
   tested now.
3. **Harness placement:** swap `JackdawApp` to show `VaultProofView`, or add it
   behind a nav from `SkeletonView`? Either works; recommend swapping for the
   duration of the slice.

## Related
- ADR 0001 (write mechanism, gotchas, verification gates): `docs/adr/0001-obsidian-write-mechanism.md`
- Build order (Slice 1 in context): `docs/build-order.md`
- ADR 0003 (SwiftData arrives Slice 2): `docs/adr/0003-persistence-swiftdata.md`
