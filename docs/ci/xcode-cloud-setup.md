# Xcode Cloud setup — owner runbook

Implements **ADR 0006** (Accepted). This is the **owner-only** side of Phase 1:
Xcode Cloud stores its workflow in App Store Connect, not in the repo, so it can't
be scripted or committed — it's a one-time GUI setup. The repo-side prerequisite
(a shared scheme) is already done; this runbook is the rest.

> **Guardrails (from ADR 0006) — do not widen these:** cloud runs **unit tests
> only**; triggers fire **only** on PR-to-`main` and merge-to-`main`, never on
> `claude/*` / `slice-*` / WIP branches; the **agent never creates, edits, or
> triggers** Xcode Cloud workflows.

---

## What's already in the repo (agent-side, done)

- **Shared scheme `Jackdaw`** (`Jackdaw.xcodeproj/xcshareddata/xcschemes/Jackdaw.xcscheme`).
  Xcode Cloud can only see *shared* schemes. Its **Test** action lists **only
  `JackdawTests`** — so the cloud structurally cannot run `JackdawUITests` (those
  stay owner-driven locally). Its **Archive** action uses Release, so the same
  scheme serves Phase 2 (TestFlight) later.
- **No `ci_scripts/`** — the project has zero SPM/CocoaPods/Carthage dependencies,
  so there's no custom clone/resolve step to script. (If a dependency is ever
  added, revisit — a `ci_post_clone.sh` may then be warranted.)

## Step 0 — Verify the scheme locally FIRST (must do before wiring the cloud)

The scheme was authored without Xcode in the loop (the remote session has no
Xcode), so confirm it before relying on it:

1. Open `Jackdaw.xcodeproj` in Xcode 26.
2. **Product ▸ Scheme ▸ Manage Schemes** — confirm `Jackdaw` is listed and
   **Shared** is checked.
3. Run the unit tests via the scheme and confirm green:
   ```
   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
     -scheme Jackdaw -destination 'platform=iOS Simulator,name=iPhone 17' \
     -only-testing:JackdawTests -derivedDataPath <scratch>
   ```
   (Same recipe as `docs/STATUS.md`. `-only-testing:JackdawTests` mirrors what the
   scheme's Test action already scopes to.)
4. If Xcode offers to "upgrade" the scheme, accept and commit the diff — that just
   normalizes the hand-authored XML to Xcode's exact format.

If the scheme doesn't resolve for any reason, the bulletproof fallback is to let
Xcode regenerate it: Manage Schemes ▸ delete `Jackdaw` ▸ Xcode recreates it ▸
check **Shared** ▸ edit its Test action to include **only** `JackdawTests` ▸
commit. Overwriting the committed file is fine.

## Step 1 — Create the "PR CI" workflow (Phase 1)

In Xcode: **Product ▸ Xcode Cloud ▸ Create Workflow** (or App Store Connect ▸ your
app ▸ Xcode Cloud). On first run it will prompt you to **grant access to the
GitHub repo** (installs Apple's GitHub app on `jimcasey/jackdaw`) — approve it.

Configure the workflow:

- **Name:** `PR CI`
- **Start Condition:** **Pull Request Changes** → target branch **`main`**.
  (Remove any default "Branch Changes" condition so it does *not* fire on every
  branch push.)
- **Environment:** latest stable Xcode 26.x / macOS image.
- **Actions:** a single **Test** action —
  - Scheme: **Jackdaw**
  - Destination: an iOS Simulator (e.g. iPhone 17)
  - (The scheme already restricts tests to `JackdawTests`; no UI tests.)
- **Post-Actions:** none for Phase 1 (no TestFlight here — that's Phase 2).

Save. Xcode Cloud kicks a first build.

## Step 2 — Prove it green on a real PR

Open (or reuse) a PR into `main` and confirm the `PR CI` check runs and passes on
the PR. This is the "prove the cheap path green before wiring the expensive one"
gate from the ADR.

## Step 3 — Make it a required check (Decision 2)

Once `PR CI` is demonstrably green: **GitHub ▸ repo Settings ▸ Branches ▸ the
`main` protection rule ▸ Require status checks to pass ▸** add **`PR CI`**. That
upgrades it from advisory to an actual merge gate — `main` "always builds and
passes unit tests" becomes enforced.

## After Phase 1 is green

Tell the agent, and it will flip the **Xcode Cloud** section of
`docs/dev-workflow.md` from "future" → "active" with the real trigger config (its
own small PR). **Phase 2** (TestFlight on merge-to-`main`) is a second workflow
that reuses this same `Jackdaw` scheme's Archive action — set up separately when
you're ready.
