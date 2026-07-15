---
description: Refresh docs/STATUS.md so Jackdaw can be resumed in a new or remote session
argument-hint: [optional note, e.g. "mid-Slice-6" or "before switching to laptop"]
---

Prepare this Jackdaw session to be handed off to a new or remote Claude Code
session. Extra context for this handoff: $ARGUMENTS

The goal: make the **git repo** a complete, self-sufficient snapshot, because a
new/remote session only sees what is committed and pushed — machine-local Claude
Code memory and this conversation's transcript do **not** travel.

Do the following:

1. **Gather current state** (do not guess — inspect):
   - `git log --oneline -15`, `git status --short`, and `git log --oneline origin/main..HEAD` (unpushed commits).
   - Read `docs/build-order.md` (the at-a-glance table is canonical) and the latest `docs/slices/slice-*.md`.
   - Note the current passing test count if known, or run the test suite (see the build recipe in `docs/STATUS.md`).

2. **Rewrite `docs/STATUS.md`** so it accurately reflects reality — keep its section
   structure (Where we are / slice progress table + next step; Key decisions with
   ADR pointers; Build & verify recipe + gotchas; the tripod & memory; What travels
   vs. what doesn't; the "before switching, push main" reminder). Update the
   slice-progress table, the "immediate next step", the test count, and the
   "Last updated" date. Fold in any new decisions or gotchas discovered since the
   last update. Keep it scannable — a fresh session reads this FIRST.

3. **Surface anything that would be lost.** If there are decisions, in-flight work,
   or gotchas that live only in this conversation (not yet in any doc, ADR, or
   persona memory), write them into the right home now: an ADR (`docs/adr/`) for a
   real decision, a slice spec, a persona's `.claude/agent-memory/` file, or
   STATUS.md. Nothing important should exist only in the chat.

4. **Report to the owner**, do NOT auto-commit or auto-push:
   - Confirm STATUS.md is refreshed and what changed.
   - List any uncommitted changes and any unpushed commits.
   - Remind the owner to **commit and push `main`** (a remote session only sees
     pushed commits), and that the build environment on the far side needs
     **Xcode 26.x + the iOS 26 SDK** to build/verify.
