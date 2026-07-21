# Slice 7 — Obsidian export (spec + implementation notes)

Spec: `docs/slices/slice-7-obsidian-export.md`. **Build-order Slice 6 =
implementation Slice 7.** This is **v1 feature-complete** once it passes on-device.

## The defining shape: near-zero new logic, high device-only surface
The whole pipeline (serializer, `RetentionMachine`, `ExportCoordinator`,
`ExportReconciler`, `ObsidianFolderDestination` incl. the tested `writeBatch`) shipped
in Slice 6 and is **reused verbatim** — Obsidian needed **no** adapter change. Slice 7
is the *acquisition/recovery/surfacing UX* around a destination that already works.
`PR CI` can only verify two new pure pieces; everything load-bearing (picker, bookmark
across cold launch, Obsidian Sync, re-grant, VoiceOver) is **owner-on-device**.

## Owner decisions (RESOLVED 2026-07-21)
- **Export trigger = Hybrid (Option C).** `keep()` fires `autoExportKept` (silent,
  Obsidian). First Keep with **no vault** → note rests `pending(.noVaultConfigured)`,
  bottom bar shows "Set up vault" — **picker never fires from the keep swipe.** Failed
  notes rest in `pending` (no auto-retry) until deliberate Retry/Re-grant. Launch also
  drains lingering `kept` (a note kept just before a kill). Race-safe with no locking:
  coordinator marks `.writing` + saves before `await`, `autoExportKept` fetches only
  `.kept`.
- **Surfacing = counts-only.** Reason-driven bottom bar (`OutboxSummary`): needsSetup
  / stuck(accessLost→Re-grant) / stuck(else→Retry); silent for empty/draining.
  `returnToInbox` (pending→inbox, plain status reset, NOT a machine event) ships as
  tested logic; the per-note stuck **list** is deferred until counts prove too blunt.

## New this slice
- `Talon/OutboxSummary.swift` — pure classifier (`OutboxState`; dominant-reason
  priority: noVault > accessLost > verifyMismatch > writeFailed). CI-tested.
- `ExportCoordinator.autoExportKept` (kept-only drain); `TriageViewModel.returnToInbox`.
- `TriageRootView` — auto-export on keep; `.fileImporter([.folder])` host for
  setup+re-grant (`VaultAccess.setVault` then re-drive `exportAll`); reason-driven
  bottom bar (moved off the leading toolbar slot, per design-lead); residue
  announcements from a *fresh* fetch (the `@Query` hasn't re-rendered yet).
- `RootView.task` — reconcile then `autoExportKept` at launch.
- **Deleted** `VaultProofView` (Slice 1 throwaway).

## Deferred / notes
- `AppleNotesDestination` is now **unused by the app** (Triage points at Obsidian) but
  left in-tree as the seam's documented second adapter — optional cleanup, flagged in
  the PR.
- Obsidian file I/O still on `@MainActor` via the seam — fine for v1 (sub-ms local
  write); offload only if on-device profiling shows a hitch.
- `pending(nil)` (reconciled interrupted write) currently reads as "Retry" in the bar
  — acceptable; a distinct "interrupted" label is a nicety, not needed.
- **Weakest-tested path even after the owner pass: re-grant (`accessLost`)** — you
  can't easily force a bookmark stale; the practical check is clear-vault/rename-folder.
