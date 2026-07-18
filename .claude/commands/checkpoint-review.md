---
description: Run the tripod + code-review checkpoint review on the current PR
argument-hint: [optional PR number or focus, e.g. "#12" or "focus on the retention state machine"]
---

Run a checkpoint review on the pull request for the current branch (or the PR in
$ARGUMENTS). This is the judgment gate described in `docs/dev-workflow.md`.

We do **not** use a separate generic reviewer agent — reviews reuse the tripod on
the dimensions they own, plus the built-in line-level review.

Do the following:

1. **Identify the change under review.** Determine the PR (current branch's PR, or
   the one named in $ARGUMENTS) and get its diff: `git diff origin/main...HEAD`,
   or the PR files via the GitHub MCP tools. Read enough of the diff to route it.

2. **Route to the right reviewers** — calibrate to the change, don't over-review
   (guidance in `docs/dev-workflow.md`):
   - **tech-lead** — always, for any code change: architecture fit, Swift/SwiftUI
     correctness, the seams, test coverage, iOS platform naivety.
   - **design-lead** — only if the PR touches UI: HIG, native feel, navigation,
     accessibility (Dynamic Type, VoiceOver, contrast).
   - **product-lead** — if the PR changes scope or user-facing capability: is this
     in v1, and does it hold the **funnel-not-archive** line (no drift toward
     organizing/browsing/history)?
   - **`/code-review`** (built-in skill) — for line-level correctness, reuse,
     simplification, efficiency. Mechanical, complements the personas' judgment.

   Invoke the needed personas (in parallel where independent) and run
   `/code-review`. Give each reviewer the diff and any linked slice/ADR.

3. **Let them disagree.** Do not smooth the personas into consensus — surface
   genuine tension and name the tradeoff. A review where everyone rubber-stamps
   added no signal. The owner arbitrates.

4. **Consolidate and post.** Merge the findings into one structured review on the
   PR (GitHub MCP tools — a single review with the highlights, most-important
   first; use inline comments for line-specific points). Group by reviewer or by
   severity. If a finding is a real architectural decision rather than a fix,
   flag it for an ADR (`/adr`) instead of burying it in a comment.

5. **Report to the owner:** the headline verdict (ship / fix-then-ship / rethink),
   the top few issues, and any point where the personas disagreed and the owner
   needs to make the call. Review output stays as PR comments — don't commit it.
