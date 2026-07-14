---
name: decision-obsidian-write
description: ADR 0001 — how Jackdaw writes kept notes into the Obsidian vault; folder-write chosen (preferred topology T2 = local vault + Obsidian Sync); write mechanism is coupled to the vault's sync engine.
metadata:
  type: project
---

**ADR 0001 (`docs/adr/0001-obsidian-write-mechanism.md`) decides the Obsidian vault
write mechanism.** Chosen: **direct folder write into the Obsidian vault folder via a
persisted security-scoped bookmark** (subsystem codename *Talon*, behind an
`ExportDestination` protocol). **Runner-up / sanctioned fallback: git commit+push** to
the owner's GitHub-backed vault.

**Why:** Retention model is "hold until sync confirmed" (settled owner decision
2026-07-14) — the write MUST return a reliable success signal. Folder-write gives a
synchronous write-then-verify confirmation with zero per-note friction and no
third-party deps (best walking-skeleton fit). Git-push gives the *strongest*
confirmation (remote-of-record) but carries libgit2/SPM interop + credential weight
that fights early de-risking. Share Sheet (can't confirm, per-note friction) and
`obsidian://` URL scheme (fire-and-forget, no return signal; Advanced URI is a
3rd-party plugin) were disqualified by the confirmation requirement.

**Sync-backend coupling (added 2026-07-14 after owner input):** The write mechanism and
the vault's sync engine are COUPLED — the write choice dictates where the vault lives,
which dictates the viable sync engine. Owner's real setup: **Obsidian Sync** is the live
iOS↔macOS path; **GitHub is manual backup only**; open to relocating the vault; hard
requirement = files keep syncing between the iOS and macOS Obsidian apps. Three clean
topologies:
- **T2 (RECOMMENDED):** vault stays LOCAL (On-My-iPhone/Obsidian), keep Obsidian Sync,
  Jackdaw folder-writes into the local vault folder; Obsidian Sync propagates. No
  migration. Correction to an earlier assumption: the local container IS Files-reachable
  and picker-navigable, so keeping Obsidian Sync does NOT break folder-write.
- **T1:** vault in iCloud Obsidian folder, sync via iCloud, DROP Obsidian Sync. iCloud
  Obsidian sync on iOS is reported flakier/slower than Obsidian Sync. Fallback if T2's
  on-device write check fails.
- **Git:** now the LEAST-preferred — GitHub is backup-only, so a push lands in the backup
  remote, NOT the live sync path; would only work if owner migrates his whole sync
  backbone to git. Downgraded from original "strong runner-up" framing.
Never run two sync engines on one vault (Obsidian guidance).

**How to apply:**
- Do not relitigate this unless the on-device check fails. Adapter is swappable behind
  `ExportDestination`, so topology can flip without redesign.
- ONE remaining owner-verification gate: on device, confirm (a) the document picker
  returns a PERSISTENTLY WRITABLE security-scoped bookmark into Obsidian's local
  container, and (b) Obsidian + Obsidian Sync cleanly ingest an externally-written .md
  with our frontmatter (no ignore/dupe). Public sources confirm Files-reachability but
  not persistent third-party write into Obsidian's container.
- "Confirmed" = bytes in the on-device vault folder; cross-device propagation is the sync
  engine's job (Obsidian Sync under T2), same durability as any note Obsidian writes
  locally before syncing.
- The note serializer (md + YAML frontmatter) and retention state machine
  (kept→pending→writing→confirmed→deleted; delete only on confirmed) live ABOVE the
  seam and are reused for every destination including the Apple Notes milestone.
- Apple Notes milestone will likely use Share Sheet plumbing (no clean Apple Notes
  write API); that write call is NOT reused by the Obsidian adapter, but the layers
  above it are. Reusable value = serialization + state machine, not the write call.
- "Confirmed" for folder-write to an iCloud vault = bytes in the LOCAL iCloud mirror,
  not a confirmed iCloud upload. Sufficient for single-device; note this if multi-device
  ever comes up. Git-push is the stronger remote-durable guarantee.

Constraints this respects (from `docs/prd/mvp-scope.md`): single user/device, iOS
native SwiftUI/SPM, no backend, precise-GPS + timestamp in YAML frontmatter, Obsidian
is the only shipped v1 destination.
