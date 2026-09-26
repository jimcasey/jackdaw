# CLAUDE.md

Project context for Claude Code. Loaded into every session and every subagent —
keep it lean; put depth in linked notes and decision records, not here.

## Project

- **What:** _TBD — one or two lines on what this is and what it isn't._
- **Status:** Empty project. No decisions recorded, no product code yet.
- **Scope instinct:** favour the smallest thing that works end to end. Resist
  building product surface before the data and access model are actually
  understood.

## How this repo works

Deliberately light. There is no product/design team here — just the main session
plus one research subagent.

- **Main session builds.** Writes and edits code, runs things, makes the calls.
- **`explorer` subagent researches.** Hand it the heavy spelunking — mapping
  framework surfaces, data shapes, auth flows, API shapes, framework gaps. It
  works in its own context and returns a tight digest, so raw research doesn't
  crowd the main thread. Findings worth keeping land in `docs/notes/`. Invoke it
  by name ("have the explorer map X") or let it pick up research-shaped tasks on
  its own.
- **Decisions get recorded.** Real choices (stack, architecture, data model) get
  a short record via `/decision` in `docs/decisions/`, so they survive across
  sessions and don't get relitigated. Not every choice — just the ones you'd want
  to be able to explain later.
- **Tests:** `/test` runs the suite and summarises what failed.

That's the whole system. Add a `reviewer` subagent (rename
`.claude/agents/reviewer.md.optional`) or more skills only if a real need shows
up, not pre-emptively.

## Owner background

Strong full-stack engineer, comfortable at architecture level; newer to Apple
platforms specifically. Explain Apple-platform choices and teach the reasoning
rather than asserting them — and cite official docs or current sources over
memory, which goes stale fast on framework APIs.

## Conventions

- **Notes:** durable exploration findings in `docs/notes/` (one topic per file).
- **Decisions:** one per file in `docs/decisions/` — context / decision /
  consequences. Keep them short.
- **Keep this file lean.** If something here grows into real depth, move it to a
  note or a decision and link it from here.
