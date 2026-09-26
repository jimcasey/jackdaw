---
name: decision
description: >-
  Record a project decision as a short, durable note (an ADR-lite). Use when a
  real choice gets made — stack, architecture, data model, or a tradeoff worth
  being able to explain later.
argument-hint: [what was decided, e.g. "use SwiftData over Core Data"]
---

Write a short decision record to `docs/decisions/`. Subject: $ARGUMENTS

Keep it lean — this is a lightweight ADR, not a document. One decision per file.

1. **Name the file** `docs/decisions/NNNN-short-slug.md`, where `NNNN` is the next
   number in that folder (start at `0001`).
2. **Write these sections and nothing more:**
   - **Context** — the situation and what forced a choice (2–4 sentences).
   - **Decision** — what was chosen, stated plainly.
   - **Consequences** — what this makes easier, what it makes harder or rules out,
     and anything to revisit later.
3. **Ground it.** If the decision rests on platform behaviour or an API
   constraint, link the relevant note in `docs/notes/` or the source it came from
   rather than restating detail.
4. Keep it to what you'd need to understand the choice a month from now. In later
   sessions, point here instead of relitigating settled ground.
