---
description: Open a pull request from the current branch to main, described from the diff
argument-hint: [optional title or focus, e.g. "Slice 6 export" or "draft"]
---

Open a pull request for the current branch against `main`. Extra direction: $ARGUMENTS

See `docs/dev-workflow.md` for the workflow this fits into.

Do the following:

1. **Check the state before opening.**
   - `git status --short` (working tree should be clean — commit first if not),
     `git branch --show-current`, and `git log --oneline origin/main..HEAD` (the
     commits this PR will contain).
   - Confirm the branch is **not** `main`. If it is, stop and tell the owner —
     work belongs on a feature branch (see the branching model in
     `docs/dev-workflow.md`).
   - Push the branch with `git push -u origin <branch>` if it isn't pushed yet.

2. **Look for a PR template** before writing the body: `.github/pull_request_template.md`,
   `.github/PULL_REQUEST_TEMPLATE/`, or the repo root. If one exists, mirror its
   section structure and fill it from the diff. Skip any template section asking
   for credentials, secrets, or anything unrelated to the code change.

3. **Write the PR from the diff, not from memory.**
   - **Title:** short and declarative. Use $ARGUMENTS if given; otherwise derive
     it from the branch and commits.
   - **Body:** what changed and why; the slice or ADR it implements (link it —
     `docs/slices/…`, `docs/adr/…`); anything the owner can't verify headlessly
     (UI on device, TestFlight, real GPS) called out explicitly so review knows
     what still needs a human on the simulator.
   - If the change follows an ADR that hasn't been ratified yet, say so — per the
     ADR-first rule, a gating decision should usually merge before its code.
   - If "draft" is in $ARGUMENTS (or the change is clearly incomplete), open it as
     a draft PR.

4. **Open the PR** against `main` with the GitHub MCP tools (find them via
   ToolSearch — `mcp__github__create_pull_request`). Do NOT merge it.

5. **Report to the owner:** the PR URL, the one-line summary, and a suggestion to
   run `/checkpoint-review` if this is a real checkpoint (a slice or a change with
   meaningful judgment calls). Then offer to watch the PR for review comments and
   CI via `subscribe_pr_activity`.
