# Write-safety patterns for a synced vault

Catalogue of options, researched 2026-09-26. This is not a decision. Prior art is in
[vault-mcp-prior-art.md](vault-mcp-prior-art.md).

The constraint behind all of these: the server copy is a full Sync peer, so a write is
broadcast to every device within seconds. Three failure modes matter:
- **Clobber**: overwriting an edit that synced in while Claude was thinking.
- **Destroy**: deletes, truncation, or binary files corrupted by a text round-trip.
- **Sprawl**: a bulk reorganisation that is wrong in 200 places.

Recovery has to work *after* the change has propagated.

## Catalogue, ranked by value-for-cost

**Cost** means implementation cost. **Friction** means friction for Claude or the user.

| # | Pattern | Protects against | Cost | Friction | Sync interaction / notes |
|---|---|---|---|---|---|
| 1 | **Granular tools + MCP annotations**: separate read/create/edit/move/delete tools. Set `readOnlyHint` on reads and `destructiveHint` on anything that overwrites, moves or deletes | Unreviewed destructive calls | Trivial | Low | In Claude, annotations drive auto-permissions: read-only tools run without per-call confirmation, destructive tools prompt ([review criteria](https://claude.com/docs/connectors/building/review-criteria)). Users can override each tool to Always allow / Needs approval / Blocked. The MCP spec treats hints as untrusted, so they are UX, not enforcement |
| 2 | **Anchor-based edits over whole-file writes**: exact unique find/replace, patch by heading/block/frontmatter key, append. `create` fails if the file exists. Overwrite needs an explicit flag | Collateral damage, truncation | Low | Low (the model prefers these tools anyway) | Smaller diffs also merge better if Sync hits a conflict (`--conflict-strategy merge`) |
| 3 | **Optimistic concurrency**: read returns a `sha256` revision, and a write takes `expected_revision`. Mismatch returns a typed conflict, and the model re-reads. Require it for overwrites | Clobber during think time (the main sync race) | Low | Low | Hash, not mtime (sync can preserve mtimes). Re-check just before the atomic rename. There is a tiny residual race window (robince's note) |
| 4 | **Cheap guards**: refuse text writes to binary paths; shrink guard (for example, >50% shrink or near-empty result needs a `force` flag); cap files touched per call; rate limit (the MCP spec says servers MUST); protect `.obsidian/` and dot-paths; atomic temp+rename with **dot-prefixed temp names** | Catastrophic one-shots (for example, an LLM "…rest unchanged" truncation), runaway loops | Low | Near zero | A non-dot temp name could be uploaded by `ob` mid-write (inferred). Never delete-then-recreate: `ob` treats a missing file as a deletion |
| 5 | **Git-backed server copy**: `.git` (hidden, so not synced) or a separate `--git-dir`. Commit **inbound sync changes first** (snapshot before write), then one commit per tool call with the tool name, args summary and attribution. Add a `revert(op_id)` tool | Everything, including bulk mistakes; gives a full audit trail | Low–medium | None until needed | Revert is just new writes that flow through Sync like any edit. Pre-write snapshots mean reverting Claude's commit doesn't revert the user's phone edits. Caveats: never run git operations that transiently remove files (`reset --hard`, checkout of other trees, stash) on the live dir. Back the repo up off-box. This largely *is* the operation journal (#9) |
| 6 | **Soft delete + feature-gated destructive tools**: delete moves the file to a server-side hidden trash, with `list_trash`/`restore` tools. Move and delete are off (not registered) until enabled | Accidental deletes | Low | Low | `.trash` is hidden and not synced, so devices **do** see the note vanish. The copy lives only on the server (plus Sync's "Deleted files"). Restore re-creates the file everywhere |
| 7 | **Read-only toggle**: server flag that leaves write tools unregistered, and/or `ob sync-config --mode pull-only` | Everything, during rollout or incidents | Trivial | High while on | Pull-only at the sync layer is structural: even a buggy server can't upload. A good first milestone |
| 8 | **Scoped write paths / Claude inbox**: write freely under `Inbox/Claude/`, with elsewhere read-only or approval-gated (cyanheads' `WRITE_PATHS`) | Blast radius | Low | Medium: blocks "organize my vault" tasks | The inbox syncs, so the user reviews on any device. Works well as a trust ramp: widen scopes over time |
| 9 | **Operation journal with undo**: an op log outside the vault, with op id, files, before/after hashes and snapshots, and `undo(op_id)` that refuses if a file changed since | Multi-file mistakes | Medium (redundant if git) | Low | StevenStavrakis implements this without git. With #5 it becomes "git log + a revert tool" |
| 10 | **Plan-then-apply for bulk operations**: `plan_reorg` returns a structured diff/plan plus a plan token bound to file revisions, and `apply_plan(token)` (destructive, needs approval) re-verifies hashes | Sprawl | Medium | Medium (two calls, one approval) | Applying as one git commit gives a one-step undo. The plan could also be written as a review note in the vault |
| 11 | **Sync-freshness gate**: refuse writes when the last "Fully synced" is stale or `ob` is wedged | Writing against a stale copy, which creates conflicts | Low–medium | Rare | `ob --continuous` can hang without exiting, so probe progress, not the process (chrisns, andyjmorgan) |
| 12 | **Proposal/staging model**: Claude writes proposals, the user approves, the server applies after re-checking the base hash. UIs: (a) review notes in a synced folder, approved by flipping frontmatter `status: approved`; (b) an Obsidian plugin diff UI (review-gate style; desktop only); (c) a web UI | Everything, with a human in the loop | High (c) / medium (a) | High: every change waits | (a) works on the phone with no app changes, but it is clunky for many small edits. Best reserved for bulk/destructive ops, or used as the path for out-of-scope writes under #8 |
| 13 | **Rely on Obsidian Sync version history** | Last resort | Zero | High at recovery time | 1 month (Standard) / 12 months (Plus), attachments 2 weeks. Restore is manual in the app (bulk restore exists). `ob` has no history commands. Set `--device-name` (for example "Claude") so its writes are identifiable. A backstop, not a design |
| 14 | **Confirmation inside the tool call**: MCP elicitation (cyanheads), or confirm-path echo (mcpvault) | Deletes | Low | Medium | The echo is weak because the model just repeats the path. Elicitation depends on the client: **whether claude.ai supports elicitation for remote connectors is unverified**. Client-side "Needs approval" (#1) covers most of the same ground |

## Combinations that fit

- **Baseline (cheap, strong):** #1 + #2 + #3 + #4 + #5 + #6. Every write is minimal, conflict-checked,
  guarded, attributed and revertible, and destructive calls prompt in Claude. Most mature prior art converges on this set
  (robince, StevenStavrakis, CTristan).
- **Rollout ramp:** #7 (pull-only), then #8 (inbox only), then baseline across the whole vault. Each step is a config change.
- **Bulk reorganisation:** #10 on top of #5. The plan is reviewed, then applied as a single commit and undone as one.
  Consider #12(a) as the review surface if approving in chat feels too thin.
- **Backstop:** #13 comes free. Name the device.

## Open questions

- Does claude.ai honour `destructiveHint` as "Needs approval" by default for *custom* (non-directory) connectors,
  or only for directory connectors? What is the default permission state?
- Does claude.ai support elicitation for remote MCP servers?
- Does `ob` ignore dot-files exactly like app Sync? This decides where temp files, `.git` and trash can safely live.
- `ob --conflict-strategy`: which gives a safer failure mode for Claude-vs-phone collisions, merge or conflict files?
