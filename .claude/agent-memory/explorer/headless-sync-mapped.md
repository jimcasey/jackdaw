---
name: headless-sync-mapped
description: Obsidian Headless Sync was mapped 2026-09-26 at v0.0.14 (source-read + GitHub issues); key constraints and where the detail lives
metadata:
  type: reference
---

Mapped Headless Sync on 2026-09-26 against obsidian-headless@0.0.14. Full, cited findings: docs/notes/obsidian-headless-sync.md.

Load-bearing facts (re-verify if the package version has moved past 0.0.14):
- `OBSIDIAN_AUTH_TOKEN` env var overrides the stored token. The derived E2E key is stored in `~/.config/obsidian-headless/sync/<id>/config.json`.
- Continuous mode = fs.watch plus a 30 s backstop. Per-file re-upload throttle is 10/20/30 s. Writes are non-atomic.
- A file missing from disk at startup is deleted remotely (by design). Same-path creation with no common base can drop the local copy silently.
- Best primary sources beyond the docs: the public tracker github.com/obsidianmd/obsidian-headless/issues (maintainer: lishid), and the npm tarball's cli.js.

**How to apply:** start from the note, then check for newer npm versions and closed issues (#19 #28 #50 #53 #54) before re-researching.
