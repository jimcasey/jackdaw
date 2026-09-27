# Architecture proposal (draft)

Draft, 2026-09-26. Synthesises the feasibility research; nothing here is decided
until it lands in `docs/decisions/`. Decided so far:
[0001 git-backed write history](../decisions/0001-git-backed-write-history.md),
[0002 always-on hosted server](../decisions/0002-always-on-hosted-server.md). Sources:
[obsidian-headless-sync.md](obsidian-headless-sync.md),
[claude-connector-mcp.md](claude-connector-mcp.md),
[vault-mcp-prior-art.md](vault-mcp-prior-art.md),
[write-safety-patterns.md](write-safety-patterns.md).

## Feasibility verdict

**Feasible.** Every piece exists today and the shape has prior art (several 2026
projects pair `ob` with a filesystem MCP server). Two things are genuinely
uncertain and need live tests before we commit:

1. **`ob` is open beta with sharp edges** — a vault folder that is missing or empty
   at startup propagates as a mass delete; same-path creates within ~3 min can
   silently lose a copy; moves can resurrect (#53); it can hang without exiting (#50).
2. **Auth path** — Claude needs real OAuth (DCR/CIMD, exact `resource` match,
   rotating refresh tokens). Cloudflare Access Managed OAuth *should* supply that
   without us writing an auth server, but it's unverified with Claude.

## Shape

```
 devices ⇄ Obsidian Sync ⇄ [ ob sync --continuous ]      one always-on VPS/container
                                     │ (files)
                               vault dir  ◄── git (separate --git-dir, off-vault)
                                     │ (files)
                          [ Jackdaw MCP server ]  Node 22+, TypeScript
                                     │ Streamable HTTP
                   Cloudflare Tunnel + Access (OAuth, owner-only policy)
                                     │
                  Claude (web / desktop / mobile via Anthropic cloud; Claude Code)
```

- **One host, two processes**, both Node: `ob` owns sync; Jackdaw owns reads,
  writes, and the git history. They share nothing but the vault directory.
- **Jackdaw never talks to Obsidian Sync directly.** All propagation goes through
  `ob`, so there's one sync implementation and one set of bugs.
- **Every change goes into git** (decision 0001), with the git dir outside the
  vault (`--git-dir` elsewhere, work tree = vault). No reliance on `ob` ignoring
  dot-folders, and git never runs a command that removes files from the live tree.
- **Supervisor with a startup guard**: refuse to start `ob` unless the vault dir
  exists, is non-empty, and contains a sentinel file. Health = sync *progress*, not
  process liveness.

## Tool surface

Reads (annotated `readOnlyHint`, run without prompting): `search` (full-text +
path + frontmatter), `read_note` (returns content + revision hash), `list`,
`links`/`backlinks`, `recent_changes`.

Writes (granular, so Claude's per-tool Always allow / Needs approval / Blocked
does the gating): `create_note` (fails if exists), `edit_note` (anchored:
find/replace, patch section, append; requires `expected_revision`),
`update_frontmatter`, `move_note` (link-aware), `delete_note` (soft), `revert`.
Destructive ones carry `destructiveHint`. Move/delete unregistered until enabled.

## Write safety: recommended baseline

The research converges on a cheap, strong baseline (patterns #1–#6):

| Layer | Covers |
|---|---|
| Granular tools + annotations; Claude per-tool permissions | Unreviewed destructive calls |
| Anchored edits, no blind overwrite, create-fails-if-exists | Collateral damage, truncation |
| Revision hash precondition on every write | Clobbering a phone edit that synced in mid-thought |
| Guards: shrink limit, per-call file cap, rate limit, no text writes to binaries, `.obsidian/` protected, atomic dot-temp + rename, never delete-then-recreate | One-shot catastrophes, runaway loops, `ob` mis-reading a transient delete |
| Git: snapshot inbound changes, then one commit per tool call; `revert(op)` writes forward | Everything, incl. bulk mistakes — with an audit trail |
| Soft delete to server-side trash + `restore` | Accidental deletes |

Plus: plan-then-apply for bulk reorganisations; a sync-freshness gate; Sync
version history as the free last-resort backstop (`--device-name Claude`). The
owner has Sync Plus, so that backstop keeps 12 months of note history (attachments
still only 2 weeks).

### Alternatives to the baseline (for comparison)

- **Human-approval-first (proposal/staging).** Claude only writes proposals; you
  approve (review notes with `status: approved`, a plugin diff UI, or a web UI).
  Safest, highest friction — better reserved for bulk or out-of-scope writes.
- **Scoped writes (Claude inbox).** Free writes under one folder, read-only
  elsewhere. Great trust ramp, but blocks "organize my vault" on its own.
- **App-backed instead of headless.** Run the Obsidian app + Local REST API plugin
  on an always-on Mac: link-aware renames and trash come free from Obsidian, but it
  needs a desktop session running and adds a plugin dependency. Rejected: there's
  no always-on machine (decision 0002), and `ob` is exactly the headless piece
  this avoids.
- **In-call confirmation (elicitation).** Works in Claude Code, not claude.ai
  today — can't be the primary gate.

## Rollout ramp

1. **Read-only**: `ob` in `pull-only` mode — structurally cannot upload even if
   Jackdaw is buggy. Proves hosting, OAuth, search quality.
2. **Inbox writes**: bidirectional sync, writes scoped to one folder.
3. **Whole-vault edits** with the full baseline; move/delete enabled last (move
   needs link rewriting, the most intricate piece).

## Still open

- **Provider** for the always-on host (decision 0002 sets the constraints).
- **Rest of the write-safety baseline** beyond git — revision preconditions,
  anchored edits, guards, soft delete — to confirm as a decision once the tool
  surface is designed.
- **Live `ob` tests** against a throwaway vault: latency, concurrent-edit merge,
  same-path create, move persistence, token lifetime.
- **Cloudflare Access + Claude OAuth** end-to-end test.
