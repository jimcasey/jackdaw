# Obsidian Headless Sync as a long-running two-way peer

Researched 2026-09-26 against `obsidian-headless@0.0.14` (published 2026-07-30).
Open beta: expect behaviour to change, and re-check this note against newer
versions.

**Question:** can Headless Sync run as a reliable, long-running, two-way sync
client for a vault that our service also reads and writes on disk?

**Short answer:** it's feasible, and this is a use case Obsidian names itself
("providing agentic tools vault access"). It is not yet reliable enough to trust
without guardrails. It really is two-way, it picks up external writes through a
filesystem watcher, and it merges Markdown. But the tracker has open data-loss
and hang bugs, writes to disk are not atomic, and a few merge paths can drop an
edit. Our service must treat the vault as shared and contested, and must keep its
own safety net rather than rely only on Sync version history.

Evidence tags used below:
- **[doc]** official docs
- **[pkg]** the README shipped in the npm package
- **[code]** read from the bundled `cli.js` (minified JS, beautified)
- **[issue]** the public GitHub tracker, `obsidianmd/obsidian-headless`
- **[infer]** my inference

---

## Install and run

- **Package and runtime:** `npm install -g obsidian-headless` installs the binary
  `ob`. Needs Node >= 22 (`engines`). License is `UNLICENSED`, meaning
  proprietary; the maintainer says use and integration are fine under
  obsidian.md/license and /terms [pkg][issue #39]. Redistributing it inside a
  Docker image is an open question [issue #52].
- **Dependencies:** `better-sqlite3` (native; needs a prebuild or a toolchain)
  and `commander`. The `btime` native addon ships only for macOS and Windows. On
  Linux, file creation times are simply not preserved [pkg].
- **Commands** [pkg]:
  - `ob login`, `ob logout`
  - `ob sync-list-remote`, `ob sync-list-local`, `ob sync-create-remote`
  - `ob sync-setup --vault <id|name> [--path] [--password] [--device-name] [--config-dir]`
  - `ob sync [--path] [--continuous]`
  - `ob sync-config …`, `ob sync-status`, `ob sync-unlink`
  - `--json` gives machine output and turns off interactive prompts.
- **One-shot vs continuous:**
  - `ob sync` runs to "Fully synced", then exits.
  - `ob sync --continuous` stays up, holds a WebSocket to `*.obsidian.md`,
    watches the filesystem, and also re-runs a sync pass every 30 s [code].
- **One process per vault:** a lock file, `<vault>/<configDir>/.sync.lock`,
  enforces this. The lock has had bugs on ext4 (fixed, #31) and exFAT (open, #16).
- **Running as a service:** the docs give no systemd or Docker guidance [doc].
  Community reports run it under systemd and in `node:22-slim` / LXC containers
  [issue #42 #50 #53 #54]. SIGINT and SIGTERM are handled [code], but one report
  says SIGTERM didn't stop it within 90 s [issue #25, open].
- **Do not run Headless Sync and desktop-app Sync on the same device** [doc].

## Auth and credentials

- **Login:** `ob login [--email] [--password] [--mfa]` prompts for anything
  omitted, and asks for a 2FA code if the account has it [pkg]. It stores an
  account token in the file `auth_token` (mode 0600). The file lives in
  `$XDG_CONFIG_HOME/obsidian-headless/` (default `~/.config/obsidian-headless/`)
  on Linux, and in `~/.obsidian-headless/` on macOS and Windows [code].
- **Non-interactive use:**
  - The environment variable `OBSIDIAN_AUTH_TOKEN` overrides the token file
    [code]. So a server can run with an injected secret and never run `ob login`
    there. The token has to be minted once, somewhere, with `ob login`.
  - `sync-setup --json --password …` is fully non-interactive [pkg].
  - [infer] Token lifetime and expiry are unknown.
- **E2E password handling:**
  - `sync-setup` derives the vault key from the password and stores the
    **derived key and salt**, not the password, in
    `<cfg>/sync/<vaultId>/config.json` (mode 0600) [code].
  - Anyone with that file can decrypt the vault, so treat it as a secret.
  - Per-vault sync state is kept alongside it: `state.db` (SQLite) and `sync.log`.
- **Standard (non-E2E) vaults:** issue #51 (open) reports that `sync-setup` fails
  with "Password not provided."

## Direction and change detection

- **Modes** [pkg][code]:
  - `bidirectional` (default)
  - `pull-only` downloads only and ignores local changes
  - `mirror-remote` downloads only, **reverts local changes, and deletes
    local-only files**
- **Local change detection** [code]:
  - Uses Node `fs.watch`. On macOS and Windows it is recursive. On Linux it adds
    one inotify watch per directory, so large vaults may need a higher
    `fs.inotify.max_user_watches`.
  - Every startup does a full scan.
  - Change detection is based on mtime and size; a file is hashed only when
    those differ.
  - Watch events are reconciled immediately. The 30 s timer is a backstop.
- **Upload throttle** [code]: a file already synced once is not re-uploaded
  until 10 s, 20 s or 30 s after its last sync (under 10 KB, under 100 KB, larger
  files respectively). New files go up immediately. Remote changes arrive by
  WebSocket push and are applied right away.
- **Hidden paths** [code][doc]: any path segment starting with `.` is ignored,
  except the config directory. On Linux the config directory is not watched
  either, so local config edits upload only at the next restart [issue #54, open].
- **Deletions are propagated both ways.** On startup, anything tracked in
  `state.db` but missing on disk is deleted **on the remote** [code]. The
  maintainer confirms this is by design: "If you forced the scan to not see a
  file on disk then the expected behavior is to delete the file" [issue #28].
  Remote deletions arrive as a hard `unlink` locally, with no trash [code].

## Conflicts

**Official semantics for the desktop app** [doc: help/sync/troubleshoot]:
- Markdown is merged with diff-match-patch.
- All other files, canvas included, are "last modified wins".
- Settings JSON is key-merged.
- An optional "conflict file" mode writes
  `name (Conflicted copy <device> YYYYMMDDHHMM).md`.

**What the headless code actually does** (the default is
`conflictStrategy: "merge"`) [code]:
- **`.md` changed on both sides:** a three-way merge. The base is the last server
  version this client knew; the other two inputs are the local file and the new
  server version. With the `conflict` strategy, the local version is instead
  saved as a "Conflicted copy" and the server version is written in place.
- **`.md` with no common base** (the same path created independently on both
  sides):
  - If the local file is less than 3 minutes old, the **server copy overwrites
    local**.
  - Otherwise the newer mtime wins.
  - The losing local content is never uploaded, so it is **not in version
    history**. [infer] This is a silent-loss path for notes we create.
- **Non-`.md` files outside the config directory, changed on both sides:** logs
  "Rejected server change", then uploads the local copy. [infer] Local wins,
  which is not "last modified wins". The server's version should survive in
  version history.
- **Config JSON:** a shallow key merge in which server keys overwrite local ones.
  That is the opposite of what the docs say.
- **Remote folder vs local file at the same path:** the local file is renamed
  `name (Conflicted copy).ext`.
- **Race in the merge path** [infer]: the code reads the local file, merges, then
  writes. Nothing re-checks between the read and the write, so a write our
  service makes in that window is overwritten.
- **Writes are not atomic** [code]: plain `fs.writeFile`, with no temp file and
  rename. Our reader can see a partly written file.
- **Field reports:**
  - #42 reported concurrent-edit loss under both strategies. The reporter later
    found the test was flawed: external writes on the desktop app are picked up
    by a roughly 60 s scan. The issue was closed.
  - #15 (fixed): an older engine race re-uploaded stale or empty copies.

## What syncs

- **Always synced:** `.md`, `.canvas`, `.base` [code].
- **Attachments:** image, audio, video and PDF are on by default. `unsupported`
  (every other extension) is off by default and set with `--file-types` [pkg][code].
- **Config** [code]: in the desktop app's defaults the `app`, `appearance`,
  `hotkey` and `core-plugin*` categories are on. Headless setups show "none
  (config syncing disabled)" until you set `--configs`.
  `workspace*.json`, `node_modules` and dot-paths are never synced.
- **Selective sync:** `--excluded-folders`. An include-list does not exist yet
  [issue #37].
- **Per-file size cap** [code][doc]:
  - The client default is 199 MB, and the server can override it at connect time.
  - Plan limits: Standard 5 MB per file, 1 GB total, 1 vault. Plus 200 MB per
    file, 10–100 GB total, 10 vaults.
  - Devices are **unlimited** on both plans, so the headless client uses no
    device slot [doc: help/sync/plans].
- **History and recovery** [doc: help/sync/version-history, plans]:
  - Note versions are kept 1 month on Standard and 12 months on Plus.
  - Attachment versions, and deleted attachments, are kept 2 weeks.
  - Deleted files are restored from the **desktop or mobile app**
    (Sync → Deleted files). The headless CLI has no restore command. The protocol
    has a `deleted`-list operation, but no CLI command exposes it [code].
- **Renames** upload as new-path-plus-delete. Issue #53 (open, 0.0.14): a file
  moved locally with `mv` reappeared at its old path about 2 minutes later.
  **This matters directly to us, because we plan to move and rename notes.**

## Beta limits and known issues (open as of 2026-09-26)

- **#19 / #28:** remote files deleted unexpectedly. They are unreproduced; the
  maintainer suspects network, virtual or cloud-synced filesystems.
- **#50:** hangs at "Connecting..." after a reboot, with no timeout. #41 and #17
  were earlier fixes for the same kind of problem.
- **#53:** moved files get resurrected at their old path.
- **#54:** config changes on Linux are not detected.
- **#25:** SIGTERM shutdown.
- **#51:** setup of a standard-encryption vault fails.
- **Health signal:** there is none beyond log lines. "Fully synced" is the only
  heartbeat [issue #50].

## Terms

- The ToS forbid using the Services "to provide a service for others". A
  single-owner personal tool is fine; hosting it for other people is not [doc:
  obsidian.md/terms].
- The ToS also forbid reverse-engineering or decompiling. This note relied partly
  on reading the shipped JS; issue threads, including the maintainer, discuss
  `cli.js` internals openly.
- Nothing in the terms forbids automated clients; Obsidian markets Headless for
  exactly this use.

## Implications for Jackdaw [infer — for the main session to decide]

- **Write atomically:** write to a temp file, then rename. Do it quickly, and
  re-read the file just before writing.
- **Keep an independent snapshot or journal** of every file we change (for
  example a git repo of the vault). The Sync history can't be driven from the CLI,
  and some loss paths never reach it.
- **Never let the vault directory be empty or unmounted while `ob sync` runs.**
  An empty scan means "delete everything remotely".
- **Supervise the process.** Watch the log for liveness and restart when it
  hangs. Pin the package version.
- **Avoid creating a note at a path another device may be creating at the same
  moment** (daily notes!). Prefer appending, or use unique names.
- **Treat moves as risky** until #53 is resolved.

## Open questions for a live test (owner's account, throwaway vault)

1. **External-write latency:** how long from our write on disk to the note
   appearing on phone and desktop? Is the 10/20/30 s re-upload throttle visible?
2. **Concurrent edits:** edit the same note on the server and on the phone within
   the same few seconds. Does the merge keep both edits? Does it behave the same
   with the `conflict` strategy?
3. **Same-name creation:** create a note of the same name on both sides within
   3 minutes. Is one version lost, and is it anywhere in version history?
4. **Moves:** does a `rename` on the server stick? Try to reproduce #53.
5. **Token lifetime:** how long does an `OBSIDIAN_AUTH_TOKEN` stay valid? Does
   `ob logout` elsewhere, or a password change, revoke it?
6. **Version-history attribution:** do our writes appear in version history under
   `--device-name`, and can they be restored from the app?
7. **Resilience:** run for days. Measure reconnects after network loss and after
   a host reboot (#50).
8. **Deleted-file restore:** delete a note on the server and check that it
   restores from the app.
9. **Scale:** memory and CPU use, and inotify watch count, on the owner's real
   vault size.

## Sources

- https://obsidian.md/help/headless
- https://obsidian.md/help/sync/headless
- https://obsidian.md/help/sync/troubleshoot
- https://obsidian.md/help/sync/plans
- https://obsidian.md/help/sync/version-history
- https://obsidian.md/help/sync/settings
- https://obsidian.md/terms
- npm `obsidian-headless@0.0.14`: README, and `cli.js` read locally
- https://github.com/obsidianmd/obsidian-headless/issues (#15 #16 #19 #25 #28 #31
  #37 #39 #42 #50 #51 #52 #53 #54)
