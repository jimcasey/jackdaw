# ADR 0001 — Obsidian vault write mechanism

> **Status:** Accepted — T2 (folder-write, local vault, Obsidian Sync). One
> implementation-level gate (writable bookmark) deferred to the walking skeleton.
> **Date:** 2026-07-14
> **Owner of decision:** tech-lead, arbitrated by owner
> **Codename:** the write-adapter subsystem is *Talon* (the claw that sets the
> note down in the vault). It sits behind a single `ExportDestination` seam.

## Context

Jackdaw's export stage must get a kept note — a markdown body plus **YAML
frontmatter carrying a capture timestamp and precise GPS location** — into the
owner's Obsidian vault. This is the critical-path blocker for v1: it gates both
the export UX and the retention model.

Four settled owner decisions constrain the choice:

1. **Retention is "hold until sync confirmed."** The note stays local and is
   deleted **only after the write is verified to have succeeded.** The mechanism
   MUST return a reliable success/failure signal. "Fire and hope" mechanisms are
   at a serious disadvantage.
2. **Arbitrary YAML frontmatter must travel with the note** (timestamp + precise
   GPS).
3. **Single user, single device, iOS-native (SwiftUI/SPM), no backend by
   default, no Mac-side component.**
4. **Apple Notes is a sanctioned intermediate de-risking milestone**, not a
   shipped destination. We want the walking-skeleton work to carry forward.
5. **Walking-skeleton rule:** the mechanism must be reachable early on a real
   device via TestFlight, not only in a dev environment.

### iOS platform facts the owner needs (you are new to iOS — these are the load-bearing ones)

Every iOS app runs in a **sandbox**: by default it can only read and write files
inside its own container. It cannot freely reach another app's files or
arbitrary folders on the device. Getting a note *out of Jackdaw's sandbox and
into Obsidian's* is the entire problem, and each candidate below is really a
different answer to "how do we cross that sandbox boundary, and do we learn
whether we made it across?"

Three verified facts shaped this decision:

- **A URL scheme (`obsidian://`) is fire-and-forget.** iOS lets you open another
  app via `UIApplication.open(_:options:completionHandler:)`. The completion
  handler's `Bool` tells you only whether iOS **successfully handed the URL to
  the other app** — *not* whether the other app did what you asked. There is no
  return channel from Obsidian back to Jackdaw saying "note written."
  ([Apple: open(_:options:completionHandler:)](https://developer.apple.com/documentation/uikit/uiapplication/1648685-openurl))
- **Obsidian on iOS can only open a vault that lives inside its own iCloud
  "Obsidian" folder or its local On-My-iPhone/Obsidian container.** It cannot be
  pointed at an arbitrary folder the way the desktop app can. So a "write a file
  to where the vault lives" strategy only reaches Obsidian if we write into
  *that specific location*.
  ([Obsidian forum: opening a vault outside the iCloud/Obsidian folder](https://forum.obsidian.md/t/feature-open-an-existing-vault-that-is-not-in-icloud-obsidian-folder-but-rather-inside-documents/53585),
  [Obsidian forum: full file system access request](https://forum.obsidian.md/t/full-file-system-access-for-the-ios-app-open-existing-vault-folder/28266))
- **A user can grant persistent, sandbox-crossing write access to one folder via
  a security-scoped bookmark.** The user picks a folder once with the system
  document picker; iOS vends a security-scoped URL; we save a *bookmark* (a
  durable, relocatable reference) to disk; on later launches we resolve the
  bookmark and call `startAccessingSecurityScopedResource()` to write. This is
  the sanctioned way to hold write access to a folder outside our container.
  ([Apple: security-scoped bookmark & URL access](https://developer.apple.com/documentation/professional-video-applications/enabling-security-scoped-bookmark-and-url-access),
  [SwiftLee: security-scoped bookmarks](https://www.avanderlee.com/swift/security-scoped-bookmarks-for-url-access/))

  iOS gotcha to record now, because it will bite during implementation: on iOS
  you create the bookmark with `url.bookmarkData()` (default/`[.minimalBookmark]`
  options). The `.withSecurityScope` option you'll see in tutorials is
  **macOS-only** — passing it on iOS is a mistake. On resolve you must check the
  returned `bookmarkDataIsStale` flag and re-create the bookmark if stale.

## Candidates evaluated

### A. iOS Share Sheet (`UIActivityViewController`)
User taps export, the system share sheet appears, they route the note to
Obsidian or to Files.

- **Confirmation:** Poor. The completion handler reports `completed` and the
  chosen `activityType`, but "the user tapped Save to Files" is not "the note
  landed in the vault, correctly, as a `.md` file with intact frontmatter." The
  user can also cancel. This cannot underwrite "hold until sync confirmed"
  without the owner eyeballing every export.
- **Frontmatter:** Fine — we author the file, so any YAML we want.
- **Backend/Mac:** None required.
- **Friction:** High and per-note — a manual, multi-tap routing decision on every
  export. This fights the "clear the inbox in a batch" job and the funnel ethos.
- **Verdict:** Disqualified as the primary mechanism by the confirmation
  requirement + per-note friction. Retained only as the likely plumbing for the
  Apple Notes de-risking milestone (see below).

### B. `obsidian://` URL scheme / Advanced URI
Deep-link into Obsidian to create the note.

- **Confirmation:** Disqualifying. Fire-and-forget (see platform facts). No
  signal that the note was written. "Hold until sync confirmed" is not
  implementable on top of this.
- **Frontmatter:** The Advanced URI *community plugin* can create a file with
  frontmatter, but that is a **third-party plugin the owner must install and keep
  configured** in Obsidian — an out-of-app dependency and a silent-breakage
  surface.
- **Backend/Mac:** None, but it hard-requires the Obsidian app to be present and
  a plugin installed.
- **Verdict:** Disqualified by the confirmation requirement.

### C. Direct folder write via security-scoped bookmark  ← **DECISION**
The owner picks the vault folder once (the iCloud `Obsidian/<vault>` folder, or
the local On-My-iPhone `Obsidian/<vault>` folder) via the document picker. We
persist a security-scoped bookmark. On export, Jackdaw writes a `.md` file
directly into that folder using `FileManager`.

- **Confirmation:** Strong and synchronous. The write either succeeds or throws.
  We then **read the file back and verify its bytes/size** before deleting the
  local copy. This is a real, in-process confirmation signal — exactly what "hold
  until sync confirmed" needs. (Nuance on the word "sync": see Consequences.)
- **Frontmatter:** Trivial. We compose the entire file, frontmatter included.
- **Backend/Mac:** None. Pure Foundation + the document picker.
- **Friction:** One-time folder grant, then **zero per-note friction** — export
  is fully automated. Best export UX of any candidate.
- **Walking skeleton:** Lightest dependency footprint (no third-party libraries),
  so it is the easiest to get green on a real device early. Best fit for the
  de-risking rule.
- **The catch:** Only works if the owner's iOS vault lives somewhere the Files
  document picker can reach *and* that Obsidian-iOS will read. **Resolved
  2026-07-14 (see "Sync backend coupling" below):** *both* Obsidian-iOS vault
  locations qualify — the iCloud `Obsidian/<vault>` folder **and** the local
  `On My iPhone/Obsidian/<vault>` container are exposed in Files and navigable by
  the document picker. The residual unknown is narrower: whether an external app
  can persist a *writable* bookmark into those folders and whether Obsidian then
  ingests the file. Still an on-device check.

### D. Git commit + push to the GitHub-backed vault  ← **RUNNER-UP / FALLBACK**
The owner's vault is already backed by a GitHub repo. Jackdaw commits the note as
a new file and pushes.

- **Confirmation:** Strongest of all. A push returns an explicit result from
  GitHub; success means the note reached the **durable remote of record.** This
  is the most honest possible reading of "sync confirmed" — it confirms *remote
  durability*, not just a local file write.
- **Frontmatter:** Trivial — we author the file.
- **Backend/Mac:** No component *we* build or run. GitHub is the owner's existing
  infrastructure, and this is single-user, so it does not violate "no backend."
  It does require **network at export time** — which is acceptable and even
  elegant here: offline simply means the note stays `pending` and retries, which
  is precisely the retention model, not an exception to it.
- **Cost — why it is runner-up, not the pick:**
  - **Heavy, finicky dependency.** iOS git means embedding libgit2 through a
    Swift wrapper (e.g. SwiftGit2/objective-git-style bindings) via SPM. That is
    C-interop that has historically been fiddly to build for device/arch and
    varies in maintenance health. Adding it to the *earliest* slice directly
    fights the walking-skeleton mandate, which says minimize toolchain risk while
    the app does nothing. **Needs owner verification** that a currently-maintained
    SPM-installable option exists before we'd commit.
  - **Credential handling on device** (a GitHub PAT or SSH key in the Keychain) —
    a real security surface, though single-user makes it tractable.
  - **Merge/non-fast-forward handling.** Mitigated to near-zero by writing
    append-only, uniquely-named (timestamped) files, but still a case to handle.
- **Verdict:** Downgraded 2026-07-14 by new owner input. The owner runs
  **Obsidian Sync** as the live iOS↔macOS sync path and keeps **GitHub as a
  manual backup only.** A git push therefore lands the note in the *backup
  remote*, which is **not** what the Obsidian apps read — so the note would not
  appear on either device until the owner manually pulled GitHub into the vault.
  That breaks the owner's hard requirement ("files synchronize between the iOS
  and macOS Obsidian apps"). Git push only becomes viable if the owner **migrates
  his whole sync backbone to git** (drop Obsidian Sync, make GitHub the primary
  vault sync via Working Copy + desktop Obsidian Git) — a larger change than
  staying on Obsidian Sync, plus the libgit2/credential weight. Retained as a
  fallback behind `ExportDestination`, but now the *least* attractive of the
  three viable topologies. Best confirmation strength; worst fit for the owner's
  actual sync setup.

## Decision

**Adopt Option C — a direct folder write into the Obsidian vault folder via a
persisted security-scoped bookmark — as the v1 Obsidian write mechanism**,
implemented behind a single `ExportDestination` protocol (subsystem codename
*Talon*).

Rationale, in priority order against the constraints:

1. **It genuinely confirms.** A synchronous write-then-verify gives the reliable
   success signal that "hold until sync confirmed" requires, without a human in
   the loop.
2. **Best export UX** (design-lead- and product-lead-friendly): one-time setup,
   then fully automated batch export with no per-note friction.
3. **Lightest footprint / best walking-skeleton fit:** no third-party
   dependencies, so it is the fastest path to a green TestFlight build on a real
   device.
4. **Clean frontmatter**, no external plugin dependency, no backend, no Mac
   component.

**Preferred topology (updated 2026-07-14): keep Obsidian Sync, vault in the local
`On My iPhone/Obsidian/<vault>` container, Jackdaw writes into that local folder.**
Obsidian Sync then propagates the new file to macOS exactly as it would a note the
owner typed in Obsidian itself. This keeps the owner's existing, reliable sync
engine and requires **no migration to iCloud** (see "Sync backend coupling").

**Git push (Option D) is the sanctioned fallback** but is now the least-preferred
option given the owner's Obsidian-Sync-primary / GitHub-backup-only setup (it
writes to the backup remote, not the live sync path). Both write behind
`ExportDestination`, so the choice is a swappable adapter, not an architectural
fork — consistent with the PRD's "clean internal boundaries only" stance (no
plugin system, no config UI).

### Retention state machine (mechanism-independent, applies to any adapter)
Notes move `kept → pending → writing → confirmed → deleted`. A note is deleted
**only** on `confirmed`. Any failure (throw, verify mismatch, offline) returns it
to `pending` for retry. This state machine and the note serializer (markdown +
YAML frontmatter) live *above* the `ExportDestination` seam and are reused
verbatim regardless of which adapter ships — including for the Apple Notes
milestone.

## Consequences

**Positive**
- Confirmable, automated, dependency-light export that satisfies the retention
  model and reads cleanly onto a walking skeleton.
- The serializer + retention state machine are destination-agnostic, so the
  Apple Notes de-risking milestone is not throwaway: only the thin write call
  differs (Apple Notes has no clean write API, so that milestone will most likely
  use the **Share Sheet** — Option A plumbing — which is *not* reused by the
  Obsidian adapter, but the layers above it *are*). Net: the reusable value lives
  in serialization + the state machine, not in the write call.
- If we ever need remote-of-record durability, Option D drops in behind the same
  protocol.

**Negative / risks the owner must weigh**
- **"Confirmed" means the bytes are in the vault folder on this device, not that
  they have propagated to macOS.** Cross-device propagation is the *sync engine's*
  job, not Jackdaw's: under T2, Obsidian Sync carries the file exactly as it
  carries a note the owner typed on the phone; under T1, iCloud uploads it
  (asynchronous and eventual). This is the right boundary — Jackdaw confirms the
  handoff *into* the vault; the vault's own sync guarantees the rest. It is a
  weaker guarantee than Option D's remote-confirmed push, but it is identical to
  the durability of every note Obsidian itself writes locally before syncing. If
  the owner ever wants upload confirmation (T1 only), we can poll
  `URLUbiquitousItemDownloadingStatus` / `NSMetadataQuery`, but that is likely
  over-engineering for v1.
- **Security-scoped bookmarks can go stale** (OS updates, the user moving the
  vault). We must handle `bookmarkDataIsStale` on resolve and re-prompt for the
  folder. Graceful "we lost access, re-grant the vault folder" handling is
  required, not optional.
- **iOS-specific implementation gotchas to respect:** create bookmarks with
  `bookmarkData()` (not the macOS-only `.withSecurityScope`); always pair
  `startAccessingSecurityScopedResource()` with `stopAccessingSecurityScopedResource()`;
  writes should go through `NSFileCoordinator` since another process (iCloud /
  Obsidian) may touch the folder concurrently.
- **Ships a small setup step** (first-run "pick your vault folder"). Design-lead
  should own that flow; it is a one-time cost, not per-export.

## Sync backend coupling (added 2026-07-14)

The write mechanism and the vault's **sync engine are now coupled**: whichever we
pick determines where the vault must live, and where the vault lives determines
which sync engine is viable. The owner must therefore choose his sync backend
*deliberately*, because it is no longer an independent decision. Verified facts:

- **A vault in iCloud `Obsidian/<vault>` does sync iOS↔macOS via iCloud itself,
  independent of Obsidian Sync** — this is an officially supported Obsidian
  configuration. Caveat: iCloud sync of Obsidian on iOS is *widely reported as
  slower and more conflict-prone* than the paid Obsidian Sync (users report
  multi-day syncs and occasional dropped/duplicated files).
  ([Obsidian Help — sync options](https://obsidian.md/help/sync-notes),
  [Obsidian forum — iCloud guidelines thread](https://forum.obsidian.md/t/official-guidelines-for-use-of-obsidian-use-in-icloud/83058))
- **Do not run two sync engines on one vault.** Obsidian community guidance is
  explicit: pick one. Running iCloud *and* Obsidian Sync on the same vault invites
  conflicts, duplicates, and data loss.
  ([Obsidian Rocks — sync guide](https://obsidian.rocks/beginners-guide-to-sync-obsidian-between-devices/),
  [Synch — Obsidian sync conflicts](https://synch.run/blog/obsidian-sync-conflicts/))
- **Correction to an earlier assumption:** the *local* `On My iPhone/Obsidian`
  container is **not** outside Files-reachable space. It is exposed in the Files
  app (`On My iPhone → Obsidian → <vault>`) and Obsidian Sync works fine with a
  locally-stored vault. So keeping Obsidian Sync does **not** by itself break the
  folder-write approach.
  ([Obsidian forum — local vault path in Files](https://forum.obsidian.md/t/full-file-system-access-for-the-ios-app-open-existing-vault-folder/28266),
  [MacStories — Obsidian iOS setup](https://www.macstories.net/ios/my-obsidian-setup-part-1-sync-core-plugins-workspaces-and-other-settings/))

### The three clean topologies

| # | Vault location | Sync engine | Jackdaw write | Trade |
|---|----------------|-------------|---------------|-------|
| **T2 (recommended)** | Local `On My iPhone/Obsidian` | **Obsidian Sync (keep)** | Folder-write into the local vault folder; Obsidian Sync propagates | Keeps the owner's reliable sync; **no migration**. Contingent on the on-device write check. |
| **T1** | iCloud `Obsidian/<vault>` | iCloud (drop Obsidian Sync) | Folder-write into the iCloud folder | Requires migrating off Obsidian Sync onto flakier iCloud sync. |
| **Git** | GitHub as primary | git (drop Obsidian Sync) | git commit+push | Strongest confirmation, but largest change + libgit2 weight; backup-only GitHub today. |

**Recommendation:** T2. It satisfies the owner's hard requirement (iOS↔macOS
sync) using the sync engine he already trusts, needs no migration, and gives
folder-write's synchronous confirmation. Adopting folder-write does **not** force
a move to iCloud — that was the concern, and it is not the case.

## Verification gates — status

1. **Where does the iOS vault live? — RESOLVED (2026-07-14).** Owner runs Obsidian
   Sync (iOS↔macOS), GitHub as manual backup only, and is open to relocating the
   vault. Hard requirement: files keep syncing between the iOS and macOS Obsidian
   apps. This is satisfied by T2 (local + Obsidian Sync) with no relocation
   needed.
2. **Can an external app persist a writable bookmark into the vault folder, and
   does Obsidian ingest the file? — PART (b) RESOLVED, PART (a) DEFERRED TO THE
   WALKING SKELETON.**
   - **(b) Obsidian ingests an externally-written `.md` — CONFIRMED on-device by
     the owner (2026-07-14).** Hand-dropping a `.md` into
     `On My iPhone/Obsidian/<vault>` via Files surfaced it cleanly in Obsidian on
     both iOS and macOS (via Obsidian Sync), no ignore/duplicate. This validates
     the vault-location + Obsidian-Sync half of T2.
   - **(a) The document picker returns a *persistently writable* security-scoped
     bookmark into that folder — NOT hand-checkable; it is a property of a real
     app talking to the picker.** It therefore becomes the **first proof-point of
     the walking skeleton**: the earliest thin slice must pick the vault folder,
     persist a bookmark, resolve it on a later cold launch, and write+verify a
     file — on a physical device via TestFlight. Retiring this is exactly the
     platform-risk-first intent of the de-risking rule. If it fails, fall back to
     T1 (gate 3).
3. If T2's on-device check fails, fall back to **T1** (iCloud, accept flakier
   sync) before considering **Git**. If Git ever becomes the path: confirm a
   **currently-maintained, SPM-installable** libgit2 Swift wrapper builds for
   device — do not assume the packages I know of are still healthy.

## Related
- v1 PRD: `docs/prd/mvp-scope.md` (retention = hold-until-sync-confirmed; Obsidian
  is the only shipped v1 destination; Apple Notes is a build-order milestone).
- Concept brief: `docs/prd/concept-brief.md`.
- Downstream: export UX flow (design-lead), precise-location entitlement handling
  (tech-lead), and the walking-skeleton build order (tech-lead).
