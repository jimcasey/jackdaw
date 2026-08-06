---
name: design-tensions-restart
description: Two live design tensions I flagged in the PR #16 prototype-learnings review — fresh-note re-entry vs no in-app edit surface (feeds #2/#4), and the tagging trade's counter-pressure (feeds #3).
metadata:
  type: project
---

Positions I took reviewing `docs/prototype-learnings.md` (PR #16, 2026-08-06).
Hold these consistently when #2 (PRD/nav) and #3 (tagging) reach design.
Spike design sources live at `~/Code/jackdaw-spike/docs/design/` and
`~/Code/jackdaw-spike/.claude/agent-memory/design-lead/`.

**1. Fresh-note re-entry stays — but no-triage creates an unpriced gap.**
I defend the rule (Capture always opens fresh; never resumes) — it is the line
that stops Capture becoming a notepad, and without a triage editor it matters
more. But under leaving-is-the-commit + no in-app editor + direct export, a
just-banked note is instantly unreachable: a typo seconds old is fixable only
after export+sync; an interruption mid-thought (backgrounding saves non-empty
notes; prune only removes empties) banks a fragment that exports as-is. The
spike's triage inbox caught both softly; the restart has no net.
**Why:** the scope reset priced deliberate edit-before-export, not the
seconds-after-banking case.
**How to apply:** #2/#4 must decide export *timing* relative to note-banking
and what an interrupted fragment produces — an explicit owner decision, not a
default. Do not resolve it by weakening the fresh-note rule.

**2. Tagging trade has two failure directions — name both.**
Capture speed is the constraint tagging is judged against (spike ADR 0007's
durable argument). But the reflexive failure runs both ways: a design that
taxes capture fails, and so does one that inherits 0007's untyped-forever
posture so tags are never actually applied — the owner ratified the expansion
knowing its cost; a vestigial feature doesn't honor it.
**Why:** CLAUDE.md charges me with making the trade explicit rather than
splitting the difference by reflex.
**How to apply:** in #3, present the trade with both costs priced. Also: the
spike's own record says "triage is the filing moment" — trigger-selection was
never the whole classification story, and it has zero usage evidence, so don't
over-weight it as the proven pattern.
