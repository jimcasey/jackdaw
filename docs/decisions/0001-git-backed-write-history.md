# 0001 — Every vault change goes into git

**Status:** accepted, 2026-09-26

## Context

Claude writing to the vault means every change propagates to all synced devices
within seconds, so recovery has to work *after* a mistake has spread. Obsidian
Sync's version history is per-file, restored by hand in the app, and not reachable
from `ob`. See [write-safety-patterns.md](../notes/write-safety-patterns.md) (#5).

## Decision

The server copy of the vault is tracked in git, and **every change Jackdaw makes is
committed** — one commit per tool call, attributed with the tool and a summary of
its arguments. Before each write, inbound changes that arrived via Sync are
committed first as a snapshot, so Claude's commits contain only Claude's changes.
A `revert` operation undoes a commit by writing forward (new edits that sync like
any other), never by rewinding the tree.

- The git directory lives **outside the vault** (`--git-dir`, work tree = vault), so
  it never depends on `ob` ignoring dot-folders.
- Git never runs a command that transiently removes files from the live tree
  (`reset --hard`, checkout, stash): `ob` treats a missing file as a deletion and
  propagates it ([obsidian-headless-sync.md](../notes/obsidian-headless-sync.md)).
- The repo is backed up off the host.

## Consequences

- Any Claude change, including a bulk reorganisation, is auditable and undoable in
  one step, independent of Sync history.
- Pre-write snapshots mean reverting Claude's work doesn't revert edits made on
  devices — but a revert can still conflict with later device edits to the same
  lines; `revert` must detect that and refuse rather than clobber.
- Git is the operation journal; no separate undo log.
- Doesn't replace the rest of the write-safety baseline (revision preconditions,
  anchored edits, guards) — it's the recovery layer, not the prevention layer.
  Obsidian Sync Plus (12-month history) remains the last-resort backstop.
