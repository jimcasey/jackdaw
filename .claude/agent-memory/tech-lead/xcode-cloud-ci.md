---
name: xcode-cloud-ci
description: ADR 0006 — Xcode Cloud adoption for CI + TestFlight; guardrails, quota model, and verified Apple-CI facts to avoid re-deriving or overspending.
metadata:
  type: decision
---

Backs ADR 0006 (`docs/adr/0006-xcode-cloud-ci-testflight.md`). **Status when
written: Proposed** — owner ratifies. Do NOT contradict the guardrails below;
they are the reason the ADR exists.

## The decision (two phased, owner-configured workflows)

- **Phase 1 — "PR CI":** start condition = PR Changes → `main`; action = build +
  run **`JackdawTests` only** (NOT `JackdawUITests`). Prove green on a real PR
  first. Optionally becomes a required branch-protection check (open Q2, rec yes).
- **Phase 2 — "TestFlight":** start condition = merge to `main` (or release tag,
  open Q1); action = archive + distribute to **TestFlight Internal Testing**
  (owner's device). Fires only on merge/tag, never PRs/WIP.

## Guardrails — agent must obey (structural, not just policy)

- **The agent NEVER creates, edits, or triggers Xcode Cloud workflows.** They are
  git-event-driven and owner-configured in App Store Connect. No agent action
  spends a compute-minute. Agent's job ends at "push branch / open PR."
- **Agent inner loop stays local:** simulator build + `xcodebuild test`
  (recipe in `docs/STATUS.md`). Cloud is the merge gate, not the inner-loop signal.
- **Triggers only PR-to-`main` and merge-to-`main` (+ optional tag).** Never
  `claude/*` or `slice-*` → WIP pushes cost nothing.
- **Cloud runs unit tests only; UI tests local.**
- **No workflow reconfig without explicit owner request** — a trigger change can
  multiply spend silently.
- `ci_scripts/` likely NOT needed (vanilla SwiftUI+SwiftData, SPM auto-resolves).
  Add a `ci_*` script only if a concrete build step proves necessary; flag owner.

## Verified Apple-CI facts (current 2026-07 — re-verify if framework/pricing moves)

- **Quota:** 25 compute-hours/month included with Apple Developer Program, **no
  rollover**. Paid: $49.99/100h, $99.99/250h, $399.99/1000h.
- **Compute hour = wall-clock execution time.** Apple example: 5 tests × 12 min ≈
  1 hour. Slow/parallel/UI tests multiply spend — this is why UI tests stay local.
- **Start conditions available:** Branch Changes, PR Changes, Tag Changes,
  Schedule — lets triggers target PR-to-main and merge-to-main precisely.
- **TestFlight Internal Testing** reaches the owner's registered device and accepts
  **PR/non-clean/WIP builds with NO Beta App Review** (review is external-only).
- **Cloud-managed signing:** Xcode Cloud provisions certs/profiles automatically —
  big win for an iOS newcomer; removes manual provisioning from the recurring path.
- App record + device already exist from Slice 0.

## Quota math

PR build+test ~10 min; TestFlight ~15–20 min; realistic ~5–6 compute-hours/month
→ well inside free 25h. Only overspend routes are the two things guardrails forbid.

## Open decision points (owner arbitrates; ADR recs)

1. Distribute every merge to `main` (rec: **yes**, active slice dev) vs. release
   tags only (revisit on quota pressure).
2. PR CI a required branch-protection check once green (rec: **yes**).
3. Internal testers only (rec: **yes**, no Beta App Review) vs. also external.

## Alternatives rejected

- **Status quo (manual local archive+upload from Slice 0):** recurring signing
  friction on owner, no PR build signal. Kept as implicit fallback.
- **Third-party CI (GitHub Actions macOS runners / Bitrise / Fastlane):** makes
  signing/provisioning the agent's/owner's problem (cert+profile CI secrets) —
  the exact iOS complexity Xcode Cloud's cloud-managed signing removes. Not worth
  the portability for a single-user Apple-committed app. Note: Xcode Cloud locks
  into Apple's ecosystem/quota — accepted.

## Follow-up once ratified
- Flip `docs/dev-workflow.md` "Xcode Cloud (not built yet)" section → "active".
