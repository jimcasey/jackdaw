---
description: Refresh docs/STATUS.md so Jackdaw can be resumed in a new or remote session
argument-hint: [optional note, e.g. "mid-issue-12" or "before switching to laptop"]
---

Prepare this Jackdaw session to be handed off to a new or remote Claude Code
session. Extra context for this handoff: $ARGUMENTS

The goal: make the **git repo** a complete, self-sufficient snapshot, because a
new/remote session only sees what is committed and pushed — machine-local Claude
Code memory and this conversation's transcript do **not** travel.

Do the following:

1. **Gather current state** (do not guess — inspect):
   - `git log --oneline -15`, `git status --short`, and `git log --oneline origin/main..HEAD` (unpushed commits).
   - Check the open issues and the active milestone (`gh issue list`, `gh api repos/jimcasey/jackdaw/milestones`), and read any `docs/specs/*.md` for work in flight.
   - Note the current passing test count if known, or run the test suite (see the build recipe in `docs/STATUS.md`).

2. **Rewrite `docs/STATUS.md`** so it accurately reflects reality — keep its section
   structure (Where we are + immediate next steps; Key decisions with ADR pointers;
   Build & verify recipe + gotchas; the tripod & memory; What travels vs. what
   doesn't). Update the next steps, the decisions table, the test count, and the
   "Last updated" date. Fold in any new decisions or gotchas discovered since the
   last update. Keep it scannable — a fresh session reads this FIRST.

3. **Surface anything that would be lost.** If there are decisions, in-flight work,
   or gotchas that live only in this conversation (not yet in any doc, ADR, or
   persona memory), write them into the right home now: an ADR (`docs/adr/`) for a
   real decision, an issue spec in `docs/specs/`, a persona's `.claude/agent-memory/` file, or
   STATUS.md. Nothing important should exist only in the chat.

4. **Report to the owner**, do NOT auto-commit or auto-push:
   - Confirm STATUS.md is refreshed and what changed.
   - List any uncommitted changes and any unpushed commits.
   - Remind the owner to **commit and push the working branch, then open/update
     its PR** (a remote session only sees pushed commits; changes land via PR, not
     direct pushes to `main` — see `docs/dev-workflow.md`), and that the build
     environment on the far side needs the **current stable Xcode** (26.x as of
     2026-08) to build/verify.
