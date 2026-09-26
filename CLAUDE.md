# CLAUDE.md

Project context for Claude Code. Loaded into every session and every subagent —
keep it lean; put depth in linked notes and decision records, not here.

## Project

- **What:** A service that keeps a copy of my Obsidian vault in sync using
  Obsidian Headless Sync and exposes it to Claude as a connector (an MCP server).
  Claude can **read** the vault to answer questions and **write** to it —
  organizing, editing, and creating notes — with changes syncing back to every
  device. Not an Obsidian plugin or a replacement editor.
- **Status:** Project defined; no decisions recorded, no code yet. Next: feasibility
  and architecture.
- **Scope instinct:** favour the smallest thing that lets Claude read and safely
  change real vault content end to end. Resist building surface area before the
  sync and connector models are actually understood.

## Domain reality

Two external pieces shape almost every early decision, so verify them against
current docs rather than assuming:

- **Obsidian Headless Sync** (<https://obsidian.md/help/headless>) is a standalone
  CLI client for Obsidian Sync — Node.js 22+, `ob login`, end-to-end encrypted —
  and is in **open beta**. How it behaves as a long-running sync peer (two-way
  sync, conflicts, change detection) is still to be established.
- **Claude connectors** are MCP servers. Which transport, hosting, and auth model
  a connector needs, and what the tool surface should look like, is still to be
  established.

**Writes are the risk.** Claude changing the vault means changes propagate to
every synced device. Treat safety as a design constraint from the start:
reversibility, conflict handling with edits made on other devices, and never
silently losing a note.

## How this repo works

Deliberately light. There is no product/design team here — just the main session
plus one research subagent.

- **Main session builds.** Writes and edits code, runs things, makes the calls.
- **`explorer` subagent researches.** Hand it the heavy spelunking — mapping
  Headless Sync behaviour, the MCP/connector model, vault structure, auth flows,
  and gaps. It works in its own context and returns a tight digest, so raw
  research doesn't crowd the main thread. Findings worth keeping land in `docs/notes/`. Invoke it
  by name ("have the explorer map X") or let it pick up research-shaped tasks on
  its own.
- **Decisions get recorded.** Real choices (stack, hosting, write-safety model) get
  a short record via `/decision` in `docs/decisions/`, so they survive across
  sessions and don't get relitigated. Not every choice — just the ones you'd want
  to be able to explain later.
- **Tests:** `/test` runs the suite and summarises what failed.

That's the whole system. Add a `reviewer` subagent (rename
`.claude/agents/reviewer.md.optional`) or more skills only if a real need shows
up, not pre-emptively.

## Owner background

Strong full-stack engineer, comfortable at architecture level. Teach the
reasoning behind platform-specific choices rather than asserting them — and cite
official docs or current sources over memory, which goes stale fast on beta
tooling and on MCP/connector behaviour.

## Conventions

- **Notes:** durable exploration findings in `docs/notes/` (one topic per file).
- **Decisions:** one per file in `docs/decisions/` — context / decision /
  consequences. Keep them short.
- **Keep this file lean.** If something here grows into real depth, move it to a
  note or a decision and link it from here.
