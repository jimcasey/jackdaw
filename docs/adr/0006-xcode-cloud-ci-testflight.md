# ADR 0006 — Adopt Xcode Cloud for CI + TestFlight distribution

> **Status:** Proposed — two phased Xcode Cloud workflows (PR CI, then TestFlight
> distribution), owner-configured, agent never triggers or reconfigures. Three
> open decision points below await the owner's call.
> **Date:** 2026-07-18
> **Owner of decision:** tech-lead (feasibility + CI/toolchain), **arbitrated and
> ratified by owner.**
> **Load-bearing at:** the next PR cycle — this ADR must be ratified *before* any
> Xcode Cloud workflow is created in App Store Connect (ADR-first for real
> decisions, per `docs/dev-workflow.md`). It makes the "Xcode Cloud (not built
> yet)" section of that doc concrete.

## Context

Changes now land via PR (`docs/dev-workflow.md`). Two gaps remain in that loop
that only a device-capable CI can close:

1. **No automated correctness gate on PRs.** Today the only build/test signal is
   the owner (or the agent) running `xcodebuild test` locally. There is no
   green/red status on the PR itself — nothing stops an un-built branch from
   merging. The tripod review is a *judgment* gate; there is no automated
   *correctness* gate beside it.
2. **Getting a build onto the device is a manual chore.** Since Slice 0 the
   TestFlight path has been a hand-driven Xcode **archive → upload to App Store
   Connect → TestFlight** each time the owner wants the latest on-device. That
   is exactly the toolchain friction the de-risking rule flags as the hard part
   of iOS for a web engineer — and it is now a repeated tax, not a one-time
   spike.

**Xcode Cloud** is Apple's first-party CI/CD. It builds, tests, and can
auto-distribute to TestFlight on git triggers configured in App Store Connect.
The relevant facts (verified against Apple docs, current 2026-07):

- **Quota:** **25 compute-hours/month** included with the Apple Developer Program
  membership, **no rollover**. Paid tiers add more ($49.99/100h, $99.99/250h,
  $399.99/1000h). A "compute hour" is **wall-clock execution time** of a build —
  Apple's own example: 5 tests running 12 min each ≈ 1 compute hour. Concurrency
  and test count multiply wall-clock, and therefore spend.
- **Start conditions** are configurable per workflow: **Branch Changes, PR
  Changes, Tag Changes, Schedule.** So a trigger can target "PR to `main`" and
  "merge to `main`" (or a tag) precisely, and *nothing else*.
- **TestFlight Internal Testing** distributes to the owner's own registered
  device. Internal testers may receive builds from **PRs and non-clean/WIP
  builds with no Beta App Review** — the review wait only applies to *external*
  testers.
- **Cloud-managed signing:** Xcode Cloud provisions certificates and profiles
  automatically. For an owner new to iOS, this removes the single most confusing
  part of the toolchain — manual signing/provisioning — from the recurring path.
- The **app record and the owner's device already exist** from Slice 0 (the
  walking skeleton is already on-device via TestFlight), so there is no new App
  Store Connect setup beyond wiring the workflows.

The standing concern this ADR must answer head-on: **cloud compute is a finite,
owner-managed quota, and an autonomous agent pushes commits.** The design has to
make it structurally impossible for agent activity to burn the budget.

## Decision

**Adopt Xcode Cloud with two phased, git-event-driven workflows, configured by
the owner in App Store Connect. Prove the cheap path (PR CI) green on a real PR
before wiring the expensive one (TestFlight).** This mirrors the de-risking rule:
get the pipeline green while it does the minimum, then add the pricey leg.

### Phase 1 — "PR CI" (build + unit test on PRs)

- **Start condition:** PR Changes targeting `main`.
- **Action:** build + run **`JackdawTests` only**. **Not `JackdawUITests`** — UI
  tests are slow and multiply wall-clock/compute-hours, and they need
  simulator/device interaction the owner already drives locally. UI tests stay
  **owner-driven, local**.
- **Purpose:** the automated **correctness** gate that sits *beside* the tripod's
  **judgment** gate (`/checkpoint-review`). A green build ≈ safe to merge.
- Prove it green on one real PR before proceeding to Phase 2.
- *(See open question 2 — whether this becomes a required status check in branch
  protection.)*

### Phase 2 — "TestFlight" (archive + distribute)

- **Start condition:** merge to `main` (*or* a release tag — see open question 1).
- **Action:** archive + distribute to **TestFlight Internal Testing** (owner's
  device). This is the pricier run (~15–20 min wall-clock).
- **Gating:** fires **only** on merge-to-`main` (or tag) — **never** on PRs or WIP
  pushes. Every finished slice lands on the device automatically, without a
  manual archive.

### Quota reasoning (why this fits inside the free 25h)

- PR build+test ≈ **~10 min**; TestFlight archive+distribute ≈ **~15–20 min**.
- Realistic monthly volume during active slice dev ≈ **5–6 compute-hours** — well
  inside the free 25h, with the paid tiers as headroom we do not expect to need.
- The only ways to blow the budget are the two things the guardrails below
  structurally forbid: triggering on WIP branches, and running UI tests in the
  cloud.

### Guardrails against agent overuse (a first-class reason for this ADR)

1. **Triggers only on PR-to-`main` and merge-to-`main`** (+ optional release
   tag). **Never** `claude/*`, `slice-*`, or any WIP branch. Agent WIP pushes on
   a feature branch **cost nothing** — no start condition matches them.
2. **Cloud runs unit tests only** (`JackdawTests`). UI tests stay local.
3. **The agent never creates, edits, or triggers Xcode Cloud workflows.** They
   are git-event-driven and **owner-configured** in App Store Connect. There is
   no agent action that spends a compute-minute — the agent's job ends at "push
   branch / open PR." The agent's inner loop stays **local simulator +
   `xcodebuild test`**, exactly as today (build/verify recipe in
   `docs/STATUS.md`).
4. **The agent must not reconfigure** workflows, triggers, or start conditions
   without an explicit owner request — changing a trigger can multiply spend
   silently.

### `ci_scripts/` — likely not needed

Jackdaw is vanilla SwiftUI + SwiftData with SPM dependencies, which Xcode Cloud
**resolves automatically**; no CocoaPods, no code generation, no secrets in the
build. So we expect **no `ci_scripts/`** (`ci_post_clone.sh` etc.) at adoption.
The agent may add a custom `ci_*` script **only if** a concrete build step proves
necessary (and should flag it for the owner if so) — it is a normal repo file,
not a workflow-config change.

### Setup responsibilities

| Task | Who |
|------|-----|
| Grant repo access (install Apple's GitHub app on the repo) | **Owner only** |
| Create the two workflows + start conditions in App Store Connect | **Owner only** |
| Confirm the TestFlight **internal** tester group / device | **Owner only** |
| Write this ADR | Agent |
| Add a `ci_post_clone.sh`/`ci_*` script — **only if** a custom step proves needed | Agent |
| Later flip `docs/dev-workflow.md` Xcode Cloud section from "future" → "active" | Agent (post-ratification) |

## Open decision points (Proposed — owner arbitrates)

1. **Distribute on every merge to `main`, or only on release tags?**
   *Recommendation: **every merge to `main`***, during active slice development —
   so each finished slice auto-lands on the device with zero manual steps. Revisit
   toward release-tag-only **if** quota pressure ever appears (the numbers say it
   won't at this cadence). Choosing tag-only now trades convenience for a margin
   we already have.
2. **Make PR CI a required status check in branch protection once proven green?**
   *Recommendation: **yes**, after it is demonstrably green on a real PR.* That is
   what upgrades it from advisory signal to an actual merge gate — `main` "always
   builds and passes unit tests" becomes enforced, not just intended.
3. **Internal testers only, or also external TestFlight?**
   *Recommendation: **internal-only** for now.* Jackdaw is single-user (the owner's
   device); internal testing needs **no Beta App Review** and delivers PR/WIP
   builds immediately. External testing adds review latency and audience we don't
   have. Trivial to add later if that changes.

## Consequences

**Positive**
- **An automated correctness gate on every PR** complements the tripod's judgment
  review; `main` stays green by construction, not vigilance.
- **The manual archive→upload chore disappears** — the toolchain tax the
  de-risking rule warns about stops being a per-slice cost. Finished slices reach
  the device automatically.
- **Cloud-managed signing removes provisioning from the recurring path** — the
  single most confusing part of iOS distribution for an owner new to the
  platform, handled by Apple rather than hand-wired each time.
- **First-party integration:** native App Store Connect / TestFlight wiring, no
  third-party CI credentials or macOS-runner management, and it stays current with
  Xcode/SDK releases.
- **Spend is structurally bounded**, not policy-bounded: WIP pushes match no
  trigger, UI tests never run in the cloud, and the agent has no button to press.

**Negative / accepted**
- **Ecosystem + quota lock-in.** We commit to Apple's CI and its compute-hour
  budget. Accepted: the free 25h dwarfs our ~5–6h estimate, and the walking
  skeleton already proved we're all-in on the Apple toolchain regardless.
- **The compute-hour model is wall-clock, and it silently punishes slow/parallel
  tests.** A bloated or slow `JackdawTests` suite, or accidentally scheduling UI
  tests, would eat hours fast. Mitigated by the unit-tests-only rule; worth
  watching as the suite grows.
- **A second place the toolchain can break** (workflow config, GitHub-app
  permissions, signing hand-off). Accepted: it replaces a *manual* fragile step
  with an *automated* one, and Phase 1 proves it green before Phase 2 relies on
  it.
- **CI latency on the PR loop.** A PR now waits ~10 min for a cloud result the
  agent used to get locally in seconds. Accepted: the agent keeps iterating
  locally; the cloud result is the *merge* gate, not the *inner-loop* signal.

## Alternatives considered

- **Status quo — manual local Xcode archive + upload (from Slice 0).** No new
  dependency, no quota, full control. Rejected as the steady state: it puts the
  recurring signing/archive friction squarely on the owner (the exact iOS pain
  point we're de-risking), and gives PRs **no** automated build/test signal.
  Retained implicitly as the fallback if Xcode Cloud is ever unavailable.
- **Third-party CI — GitHub Actions with macOS runners / Bitrise /
  Fastlane-on-CI.** More flexible and portable, avoids Apple-ecosystem lock-in.
  Rejected for this owner: **signing/provisioning becomes the agent's/owner's
  problem** (managing certificates and profiles as CI secrets via Fastlane
  `match` or equivalent) — precisely the iOS complexity Xcode Cloud's
  cloud-managed signing removes. macOS runner minutes and credential management
  add cost and setup an iOS newcomer shouldn't take on to get a first-party
  capability for free. Portability is not worth it for a single-user, single-app
  project already committed to Apple's toolchain.

## Related
- `docs/dev-workflow.md` — "Xcode Cloud (not built yet)" section this ADR makes
  concrete; flip it "future" → "active" once ratified and wired.
- ADR 0002 (min iOS target = iOS 26), ADR 0003 (SwiftData) — the vanilla
  SwiftUI+SwiftData+SPM stack that keeps `ci_scripts/` unnecessary.
- `docs/STATUS.md` — Slice 0 established the app record + on-device TestFlight
  path this builds on; local build/verify recipe the agent's inner loop keeps.
