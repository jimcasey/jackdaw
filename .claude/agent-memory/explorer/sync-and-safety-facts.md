---
name: sync-and-safety-facts
description: Established facts (2026-09-26) about Obsidian Sync/ob headless behaviour and MCP/Claude permission model that constrain Jackdaw write safety
metadata:
  type: reference
---

Established 2026-09-26. Full detail is in docs/notes/vault-mcp-prior-art.md and docs/notes/write-safety-patterns.md.

- Official Sync excludes dot-files and dot-folders except `.obsidian` (obsidian.md/help/sync/settings). So `.trash`, `.git` and journals stay on the server, and a soft delete still looks like a delete on every device. Not yet verified that `ob` follows the same rule.
- `ob sync-config` has `--mode bidirectional|pull-only|mirror-remote`, `--conflict-strategy merge|conflict`, `--excluded-folders` and `--device-name`. `ob` has no link-rewriting or history commands.
- obsidian-headless issues #19 and #28 (open): a file missing from the startup scan is treated as a deliberate delete and propagates. Avoid anything that makes files transiently absent. Use node-local storage, not NFS (inotify, no rescan).
- Sync version history keeps notes 1 month (Standard) or 12 months (Plus), attachments 2 weeks. Restore is only from the app UI.
- Obsidian CLI (1.12+) needs the app running. It is not usable headless.
- Claude connector review criteria: `readOnlyHint` lets a tool run without confirmation, and `destructiveHint` always prompts. Users can set each tool to Always allow / Needs approval / Blocked. MCP spec: annotations are untrusted, and servers MUST rate limit.
- Still open: claude.ai elicitation support; default permissions for custom connectors.
- Closest prior art: robince/obsidian-mcp (sha256 revision preconditions), StevenStavrakis/obsidian-mcp (transactions, unambiguous link rewrite), andyjmorgan/Obsidian-Hosted-Mcp (official `ob` + MCP).
