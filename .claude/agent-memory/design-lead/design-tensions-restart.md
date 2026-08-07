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
**RESOLVED — owner ruling, 2026-08-06 (PR #16 review):** the
seconds-after-banking case is not a concern; a typo is fixed at the
destination if it matters, and no in-app post-capture edit surface gets
built for it. The ruling is recorded in `docs/prototype-learnings.md` §4.
**How to apply now:** do not re-raise the edit gap in #2/#4. Export *timing*
and what an interrupted fragment produces remain ordinary design questions
for #4, but they are not motivated by an editing window — do not argue for
one. The fresh-note rule stands.

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
