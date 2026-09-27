# Prior art: Obsidian vault MCP servers

Surveyed 2026-09-26 from READMEs/source (nothing installed or run). Star counts
and activity are as of that date. "Verified" means read in source or official docs;
anything else is the project's own claim.

## Three architectural families

| Family | Needs Obsidian app? | Examples | Fit for Jackdaw |
|---|---|---|---|
| **In-app plugin** (Local REST API) | Yes, desktop running | coddingtonbear/obsidian-local-rest-api (~3k stars; ships its own MCP endpoint), plus wrappers: MarkusPfundstein/mcp-obsidian (~4.4k), cyanheads/obsidian-mcp-server (~690), aaronsb/obsidian-mcp-plugin (~460) | No (we have no always-on app). Useful as a design reference, especially cyanheads |
| **Filesystem, local** | No | bitbonsai/mcpvault (~1.7k), StevenStavrakis/obsidian-mcp (~735) | Tool-design reference |
| **Filesystem + headless sync, hosted** | No | andyjmorgan/Obsidian-Hosted-Mcp, chrisns/obsidian-server, nazimjamil/obsidian-vault-mcp (official `ob` + mcpvault), alexjbarnes/vault-sync (Go, reverse-engineered sync protocol), robince (= ykoellmann)/obsidian-mcp (sync-agnostic) | **Same shape as Jackdaw.** All small, all 2026 |
| **Git-backed** | No | CTristan/obsidian-git-mcp, andreymudri/vault-mcp | Pattern reference for git as the safety layer |

Official Obsidian CLI (1.12+, Feb 2026): about 115 commands over IPC, and **it needs the
app running**. It has `move`/`rename` that update links, `delete` to trash, and
`history`/`sync:history`/`sync:restore`. None of this is available in a headless
deployment. The official headless client `ob` only syncs; it has no link or history
commands. <https://obsidian.md/help/cli>, <https://github.com/obsidianmd/obsidian-headless>

## Notable servers and what they teach

**Local REST API plugin (built-in MCP)** has the richest tool surface: `vault_read/write/append/patch/delete/move/copy`,
`get_document_map`, search, `command_execute`. Safety features:
- Patch by heading, block ref or frontmatter key, with an `ifMatch` version for optimistic concurrency.
- Delete calls `app.fileManager.trashFile` and move calls `app.fileManager.renameFile`
  (verified in `src/vaultOperations.ts`). So it gets Obsidian's own link updating and trash for free, but only because the app is running.
- Refuses text read/write of binary files. Reading an attachment as text and writing it back destroys it.
- Full MCP annotations on every tool (verified in `src/mcpHandler.ts`). `command_execute` is conservatively
  marked destructive.

**cyanheads/obsidian-mcp-server** (via the REST plugin) has the most deliberate safety design:
- `write_note` refuses to clobber an existing file unless `overwrite: true`, and the error names the surgical tools instead.
- Delete always asks for confirmation through MCP **elicitation**. Clients without elicitation support cannot delete at all.
- `OBSIDIAN_READ_PATHS` / `OBSIDIAN_WRITE_PATHS` folder scopes and an `OBSIDIAN_READ_ONLY` kill switch. Tools that are
  disabled are **not registered**, so they don't appear in the tool list at all.
- Denials come back as typed errors that echo the active scope, so the model can self-correct.
- Command execution is opt-in.
- It has no move tool.

**bitbonsai/mcpvault** (filesystem): `--read-only` removes mutating tools. `delete_note`/`move_file` require
a `confirmPath` that echoes the target (weak: the model just repeats it). Trash can be `local` (`.trash`) or
`system`. Blocks `.obsidian`, `.git` and dotfiles. `move_note` does **not** rewrite links.

**StevenStavrakis/obsidian-mcp v2** (filesystem) has the most rigorous engine:
- SHA-256 `etag` returned on read, with `if_match` on edit/move/delete. A mismatch returns `REVISION_CONFLICT`.
- Every mutation is a journaled transaction with rollback. Recovery snapshots are kept 30 days and capped at 1 GiB, and
  there is a `recovery restore --id` CLI that refuses to overwrite content changed since the transaction.
- Default delete goes to a private trash. Permanent delete needs `confirm_path`.
- **Link-aware move**: rewrites wikilinks, embeds, markdown links, aliases, heading and block anchors, and
  URL-encoded paths, **but only links that resolve unambiguously**. Ambiguous links are reported and left unchanged.
  Delete leaves backlinks alone unless asked to mark them broken.
- Caveat for us: it keeps its state in `.obsidian-mcp/` inside the vault. Dot-folders don't sync (see below).

**robince/obsidian-mcp** (sync-agnostic, hosted, closest to Jackdaw's threat model).
Its design note `docs/implementation/phase-3-sync-concurrency.md` is worth reading:
- The threat model is explicitly "a phone edit synced in during the client's think time".
- Read returns `sha256:` revision. Writes take `expected_revision`. `REQUIRE_WRITE_PRECONDITIONS=true` makes
  full overwrites require it.
- Atomic temp-file + rename, re-checking the hash just before the rename. It admits the final check-then-rename
  is not a true compare-and-swap, so Sync history is the last line of defence.
- No-replace create uses a hard link.
- A 15-minute full-hash reconcile repairs missed watcher events.
- Move, folder-rename, bulk-replace and delete are each **off unless explicitly enabled**.
- JSONL audit log kept *outside* the vault.
- Dry-run previews with unified diffs. Move rewrites wikilinks.
- It explicitly chose not to build an operation ledger, conflict copies or multi-file transactions.

**andyjmorgan/Obsidian-Hosted-Mcp** (official `ob` + MCP, containerised, OAuth via OIDC):
- `create_note` fails if the note exists. `edit_note` does an exact unique find/replace. `replace_section` targets a heading path.
- Soft delete to `.trash` plus a `restore_note` tool.
- `/readyz` requires a fresh "Fully synced" heartbeat, and a supervisor restarts a stalled sync.
- Says "one replica only", because two `ob` processes fight over the lock.
- Its claim that trash is "recoverable everywhere" is wrong for Sync: `.trash` is a hidden folder and doesn't sync (see below).

**chrisns/obsidian-server** (official `ob` + filesystem MCP) is operationally sharp:
- A read-only token connects to a server instance that never registered `vault_write`.
- The health probe parses `sync.log` for progress, because `ob sync --continuous` doesn't exit when its websocket
  wedges.
- Vault storage must be node-local, not NFS: `ob` detects changes via inotify and doesn't rescan.
- Recommends `--mode pull-only` until trusted.

**CTristan/obsidian-git-mcp**: each write runs as a git transaction: lock, check clean, fetch, fast-forward, apply,
validate, commit, push. It rolls back on any failure and records the AI collaborator as commit author. Destructive tools
are off by default. **andreymudri/vault-mcp**: one commit per tool call (multi-file operations are a single commit, so
`git revert` undoes the whole operation). Delete refuses if the note has no committed version in HEAD, or if other notes link to it,
unless `confirm: true`. The response includes the exact undo command.

**Proposal and review UIs** (all Obsidian plugins, so they need the desktop app): CaFeZn/obsidian-review-gate has
proposals stored outside the vault, per-hunk accept/reject, a base-hash recheck at approve time, a journal and crash recovery.
There are also the community plugins Smart Note Agent, Thought Agent and AI Co-Editor (diff approve/reject). None are MCP-native.

## Sync facts that change the design (official docs)

- Obsidian Sync excludes "files and folders beginning with a `.`", except `.obsidian`.
  <https://obsidian.md/help/sync/settings>. Consequences:
  - A server-side `.git`, `.trash` or journal directory **stays on the server**.
  - A soft delete to `.trash` still shows up as a **deletion on every device**.
  - Atomic-write temp files should use dot-names so they never upload. (The last point is inferred: we have not
    verified that `ob` applies the same rule.)
- Sync version history keeps notes for 1 month (Standard) or 12 months (Plus), and attachments for 2 weeks. Restore happens per file or
  in bulk, from the **app UI**. <https://obsidian.md/help/sync/version-history>
- `ob sync-config`:
  - `--mode bidirectional|pull-only|mirror-remote`
  - `--conflict-strategy merge|conflict`
  - `--excluded-folders`
  - `--device-name`, which labels this client's writes in version history
- Open `ob` issues #19 and #28: headless sync deleting remote notes. The maintainers' position is that a file missing
  from the startup scan is treated as an intentional delete. **Anything that makes a file transiently absent on
  disk can propagate a delete to every device.**

## Link-aware operations: what a headless writer must do

Obsidian rewrites links on rename only inside the app (`fileManager.renameFile`), and only if "Automatically update
internal links" is on (`alwaysUpdateLinks` in `.obsidian/app.json`). `ob` does not do this. So Jackdaw has to:
1. Index every link form:
   - `[[name]]`, `[[name|alias]]`, `[[name#heading]]`, `[[name#^block]]`
   - embeds `![[...]]`
   - markdown links `[t](path%20x.md)`
   - links inside frontmatter properties
2. Resolve each link with Obsidian's rules: shortest unique basename, otherwise path; case-insensitive.
3. After the move, rewrite only links whose resolution *changes*. If the basename is still unique, a folder-only move needs no
   rewrites under "shortest" link format.
4. Emit new links in the vault's style (`newLinkFormat`: shortest/relative/absolute; `useMarkdownLinks`).
5. Report ambiguous links rather than guessing (StevenStavrakis's approach).
6. Apply all file changes as one undoable unit.

Heading renames never update links, even in the app. Each rewritten file syncs as a separate
modification, so a large rename fans out to many devices.
