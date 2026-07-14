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

- **iCloud write semantics:** writing to an iCloud-backed folder lands in the LOCAL
  iCloud mirror; upload is async/eventual. A successful local write != confirmed cloud
  upload. Fine for single-device; use `URLUbiquitousItemDownloadingStatus`/
  `NSMetadataQuery` only if upload confirmation is actually required (likely YAGNI).
