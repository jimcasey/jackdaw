---
description: Kick off or revise the product requirements doc via the product-lead persona
argument-hint: [scope to define, e.g. "v1 MVP" or "offline sync"]
---

Use the **product-lead** subagent to produce or update a PRD for: $ARGUMENTS

Direction for the product-lead:

- If the scope above is empty, define the overall v1 MVP for the app.
- Write to `docs/prd/` (one file per product area, clearly named). If a relevant
  PRD already exists, revise it in place rather than creating a duplicate.
- Keep it short enough that scope is visible at a glance. Cover, in this order:
  1. **Problem** — the user problem this solves, and who has it.
  2. **Target user & context** — who they are and the situation they're in.
  3. **Jobs to be done** — the 3-5 jobs the MVP must accomplish.
  4. **In scope for v1** — the minimal capability set.
  5. **Explicit non-goals** — what v1 deliberately does NOT do.
  6. **Success criteria** — how we'll know it worked.
  7. **Open questions** — decisions needed from the owner.
- Bias toward cutting scope. Where something is ambiguous, log it as an open
  question for the owner rather than assuming it in.
- Record the scope decisions and their rationale to your project memory.

Then summarize for the owner: the proposed scope, the sharpest non-goals, and
any point where you expect design-lead or tech-lead to push back — so the owner
can arbitrate before design or build starts.