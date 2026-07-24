---
name: ios-gotchas
description: Verified iOS platform facts (sandbox, URL scheme confirmation, security-scoped bookmarks, Obsidian-iOS vault location) for Jackdaw.
metadata:
  type: reference
---

Verified against Apple docs / Obsidian forum 2026-07-14 while writing
[[decision-obsidian-write]]. Re-verify before asserting to the owner if framework
behavior may have changed.

- **`UIApplication.open(_:options:completionHandler:)` is fire-and-forget.** The
  completion `Bool` reports only whether iOS handed the URL to the target app, NOT
  whether the target app performed the action. No return channel. => URL schemes
  (`obsidian://`) cannot underwrite a confirmed-write retention model.
  (developer.apple.com/documentation/uikit/uiapplication/1648685-openurl)

- **Obsidian on iOS can only open a vault inside its own iCloud "Obsidian" folder or
  its local On-My-iPhone/Obsidian container** — NOT an arbitrary folder (unlike
  desktop). Any "write a file where the vault lives" strategy must target that
  specific location. (Obsidian forum feature requests, still open as of 2026-07.)

- **BOTH Obsidian-iOS vault locations are Files-reachable / document-picker-navigable:**
  the local `On My iPhone/Obsidian/<vault>` container AND the iCloud
  `Obsidian/<vault>` folder are exposed in the Files app. So a third-party app CAN in
  principle bookmark either and write into it. What public sources do NOT confirm (=
  on-device check): that the picker grants a *persistently writable* bookmark into
  Obsidian's container and that Obsidian ingests externally-written files. Sources note
  general iOS sandbox friction on cross-app file operations.

- **Obsidian sync backends & coupling:** a vault in iCloud `Obsidian/<vault>` syncs
  iOS↔macOS via iCloud itself (officially supported), independent of the paid Obsidian
  Sync — but iCloud Obsidian sync on iOS is widely reported as slower/more conflict-prone
  than Obsidian Sync. NEVER run two sync engines on one vault (Obsidian guidance). A
  local-storage vault works fine with Obsidian Sync. => The chosen write mechanism is
  coupled to the vault's sync engine; see [[decision-obsidian-write]].

- **Security-scoped bookmarks** are the sanctioned way to hold persistent write access
  to a user-picked folder outside the app sandbox: user picks folder via
  `UIDocumentPickerViewController([.folder])` → iOS vends a security-scoped URL → save
  `url.bookmarkData()` → later resolve and call `startAccessingSecurityScopedResource()`
  (pair with `stop...`). iOS gotcha: use default/`[.minimalBookmark]` options — the
  `.withSecurityScope` option is **macOS-only**, do not use it on iOS. Handle
  `bookmarkDataIsStale` on resolve (re-create bookmark). Use `NSFileCoordinator` for the
  actual write since iCloud/Obsidian may touch the folder concurrently.

- **Now-playing facts (verified 2026-07-23):** `MPNowPlayingInfoCenter` is
  publish-only — a third-party app CANNOT read other apps' now-playing info (Control
  Center's view is a system privilege; DTS points askers at SiriKit media-intent
  *donation*, not any read API — forum thread 809554). `systemMusicPlayer` reflects the
  **Music app only** (not Podcasts/Spotify — thread 100187); reading the library
  requires `NSAppleMusicUsageDescription` (mandatory per Apple bundle-resources doc) +
  media-library/MusicKit authorization. `MPMusicPlayerController` does not work in app
  extensions and background reads are reported flaky. MediaRemote = private framework.
  Shortcuts has "Get Current Song" (Music only); Apple Podcasts exposes NO
  current-episode action; Overcast exposes "Get Current Episode Info" via Shortcuts.

- **Widget/control extension facts (verified 2026-07-23):** widget + Control Center
  control extensions are separate processes; sharing SwiftData with them requires an
  App Group container (skippable if the extension never touches the store, i.e. pure
  launcher). Widgets/controls CANNOT prompt for text input (`requestValueDialog` is a
  Shortcuts/Siri affordance); a control that must open the app needs its intent
  compiled into both targets and `openAppWhenRun=true`/`OpenIntent` (UIApplication is
  unavailable in extensions — Apple forums 758911/762479, WWDC23 10103).

- **ITMS-90626 — App Intent strings must not contain "apple" (hit for real,
  2026-07-23, spike #29 / PR #37):** App Store Connect delivery validation
  rejects an upload whose Siri/App Intents-visible metadata (intent `title`,
  `IntentDescription`, App Shortcut phrases) contains the word "apple" — the
  spike intent's description said "Apple Music" and the TestFlight upload
  bounced with *"Invalid Siri Support — App Intent description ... cannot
  contain 'apple'"*. Say "system music player" / "the current song" instead.
  Info.plist permission strings (e.g. `NSAppleMusicUsageDescription`'s value)
  are NOT affected — the rule bites only intents-layer vocabulary. Matters for
  slices C/D (media context) and any App Shortcut phrasing.

- **App Intents API facts verified for slice A review (2026-07-24, PR #41):**
  `AppIntent.description` requirement is `static var description: IntentDescription?`
  (OPTIONAL — Apple docs JSON), yet the canonical `static let description =
  IntentDescription(...)` (non-optional) pattern works: it compiled in this repo's CI
  (S1 probe) and its content demonstrably reached App Store Connect metadata
  (ITMS-90626 fired *on* the description) — the build-time metadata extractor reads
  the member, so don't "fix" it to optional. `AppShortcut` current init is
  `init(intent:phrases:shortTitle:systemImageName:)` with **non-optional**
  `shortTitle: LocalizedStringResource` (the optional-params variant is deprecated).
  `IntentDialog` conforms to `ExpressibleByStringLiteral`/`Interpolation` → bare
  strings fine for `requestValueDialog:` and `.result(dialog:)`.
  `AppShortcutsProvider.appShortcuts` is `@AppShortcutsBuilder static var
  appShortcuts: [AppShortcut]` — single-expression body compiles via result-builder
  inference on protocol witnesses. Every phrase must embed `\(.applicationName)`.

- **SwiftData cross-context @Query propagation — prefer `mainContext` from in-app
  intents:** a `ModelContext(container)` sibling context's `save()` propagating into
  the scene's `mainContext`/`@Query` *without relaunch* is undocumented behavior with
  a history of iOS 17.x flakiness (forum reports: background/ModelActor saves not
  refreshing @Query). An app-target App Intent whose `perform()` is `@MainActor` can
  and should write via `container.mainContext` (it's `@MainActor`-isolated) — @Query
  refresh is then guaranteed by construction for the warm-app case; the cold case is
  a fresh fetch either way. Self-created contexts also have autosave off (explicit
  `save()` needed — fine when the service saves synchronously).

- **Xcode project uses filesystem-synchronized groups (objectVersion 77,
  `PBXFileSystemSynchronizedRootGroup`):** new `.swift` files dropped into `Jackdaw/`
  or `JackdawTests/` are picked up automatically — no `project.pbxproj` edit needed
  when adding files without Xcode. Verified during the PR #41 first-compile audit.

- **iCloud write semantics:** writing to an iCloud-backed folder lands in the LOCAL
  iCloud mirror; upload is async/eventual. A successful local write != confirmed cloud
  upload. Fine for single-device; use `URLUbiquitousItemDownloadingStatus`/
  `NSMetadataQuery` only if upload confirmation is actually required (likely YAGNI).
