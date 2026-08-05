---
description: Scaffold an architecture decision record via the tech-lead persona
argument-hint: [decision, e.g. "Use SwiftData for persistence"]
---

Use the **tech-lead** subagent to draft an Architecture Decision Record for: $ARGUMENTS

Direction for the tech-lead:

- If the decision above is empty, ask the owner which decision to record before
  writing anything.
- Look in `docs/adr/` for existing ADRs and choose the next sequential number,
  zero-padded (e.g. `0007`). Name the file `NNNN-<slugified-title>.md`.
- Structure the ADR as:
  - **Title** — the decision as a short declarative statement.
  - **Status** — Proposed (default for a new ADR); later Accepted, Superseded, etc.
  - **Context** — the forces at play: problem, constraints, and relevant
    iOS/Swift considerations. Verify any platform-specific claims against
    current Apple docs rather than relying on memory.
  - **Decision** — what we're doing and why.
  - **Consequences** — what gets easier, what gets harder, what this locks in
    or rules out.
  - **Alternatives considered** — the main options rejected, and why.
- One decision per file.
- If this decision supersedes or contradicts an earlier ADR, say so explicitly
  and reference that ADR by number.
- Record the decision and any iOS/toolchain gotchas to your project memory.

Then summarize for the owner: the recommendation, the key tradeoff, and where
product-lead or design-lead might object — so the owner makes the final call.
Leave the status as Proposed until the owner accepts it.