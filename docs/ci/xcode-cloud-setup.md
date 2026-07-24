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
     -only-testing:JackdawTests -derivedDataPath /tmp/jackdaw-derived
   ```
   (Same recipe as `docs/STATUS.md`, with `-derivedDataPath` shown as a concrete
   path — use any throwaway dir. Don't type a literal `<placeholder>`: in zsh the
   `<`/`>` are redirects and you'll get `parse error near '\n'`. If `iPhone 17`
   isn't installed, pick one from `xcrun simctl list devices available`.
   `-only-testing:JackdawTests` mirrors what the scheme's Test action scopes to.)
4. If Xcode offers to "upgrade" the scheme, accept and commit the diff — that just
   normalizes the hand-authored XML to Xcode's exact format.

If the scheme doesn't resolve for any reason, the bulletproof fallback is to let
Xcode regenerate it: Manage Schemes ▸ delete `Jackdaw` ▸ Xcode recreates it ▸
check **Shared** ▸ edit its Test action to include **only** `JackdawTests` ▸
commit. Overwriting the committed file is fine.

## Step 1 — Create the "PR CI" workflow (Phase 1)

In Xcode, open the **Report navigator** (rightmost icon in the left navigator
strip, or **⌘9**), click the **Cloud** tab at the top, then **Get Started**.
(It is *not* under the Product menu.) Pick **Jackdaw** in the "Select a Product"
sheet → Next. On first run it will prompt you to **grant access to the GitHub
repo** (installs Apple's GitHub app on `jimcasey/jackdaw`) — approve it.

> If there's no **Cloud** tab / **Get Started** does nothing, it's account
> eligibility, not a UI quirk: in **Xcode ▸ Settings ▸ Accounts** confirm you're
> signed in with the Apple ID that is the **Account Holder** (or Admin) of an
> **active** Apple Developer Program membership.

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
own small PR).

---

# Phase 2 — TestFlight on merge to `main`

A **second** Xcode Cloud workflow that archives on merge to `main` and
distributes to your device via TestFlight Internal Testing (ADR 0006, Decision 1:
every merge, not tag-gated). It reuses the same shared **`Jackdaw`** scheme — its
Archive action is already Release.

> **Guardrail:** this is the pricier run (~15–20 min: build + archive + upload).
> It fires **only on merge to `main`**, never on PRs or WIP branches.

## Repo-side prep (agent-side, done — landed with this doc)

- **`ci_scripts/ci_post_clone.sh`** — sets the build number (`CFBundleVersion`)
  to the Xcode Cloud build number so each TestFlight upload is unique; a static
  build number collides on the second archive. Runs only in the cloud checkout.
- **`INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`** on the app target — the
  app uses only exempt encryption (HTTPS/system), so this declares export
  compliance up front and TestFlight won't block each build asking about it.
  *(If Jackdaw ever adds non-exempt cryptography, revisit this.)*
- **Signing:** nothing to do — the project is `CODE_SIGN_STYLE = Automatic` with a
  team set, and Xcode Cloud's **cloud-managed signing** creates the distribution
  certificate/profile at build time. This is the part that's normally painful for
  a new iOS dev, and Xcode Cloud just handles it.

## Step 1 — Create the "TestFlight" workflow

Same entry point as Phase 1 (Report navigator ▸ **Cloud** ▸ manage workflows ▸
add a workflow). Configure:

- **Name:** `TestFlight`
- **Start Condition:** **Branch Changes → `main`** (this is the merge-to-`main`
  trigger). Remove any PR condition — that's Phase 1's job.
- **Environment:** same pinned Xcode 26.x.
- **Actions:** an **Archive** action — scheme **Jackdaw**, and set the
  distribution/deployment to **TestFlight (Internal Testing)**.
- **Post-Actions / Deploy:** **TestFlight Internal Testing**.

## Step 2 — Confirm the internal testing group

In **App Store Connect ▸ your app ▸ TestFlight**, make sure there's an **Internal
Testing** group with **you (your device)** as a tester. Internal testing needs no
Beta App Review, so builds land in minutes. (A group likely already exists from
the Slice 0 TestFlight run.)

## Step 3 — Trigger and verify

Merge any PR to `main` (Phase 1's `PR CI` gates it first). The `TestFlight`
workflow archives, uploads, and the build appears in TestFlight; install it on
your device from the TestFlight app.

## Step 4 — Skip docs-only merges (recommended)

The `TestFlight` workflow fires on **every** merge to `main` — including
docs/prose-only merges that don't change the app, each a ~15–20 min archive plus
a redundant TestFlight build. Exclude them:

On the `TestFlight` workflow's **Branch Changes → `main`** start condition, add a
**Files and Folders** custom condition set to **"Don't start a build"** for
**`docs/`**, **`.claude/`**, and the root **`CLAUDE.md`** (the doc/prose paths). A
merge touching only those is skipped; any change under `Jackdaw/`, the
`.xcodeproj`, or `ci_scripts/` still builds.

> **`.claude/` is hidden** (a dotfolder) in the file picker — press **⌘⇧.**
> (Command-Shift-period) to reveal hidden items, then select it. Don't forget the
> root **`CLAUDE.md`** file, which a folder-only exclusion would miss. Equivalent
> alternative that avoids the hidden folder entirely: instead of excluding the
> doc paths, set **"Start a build"** for the code folders only — `Jackdaw/`,
> `Jackdaw.xcodeproj/`, `ci_scripts/`.

**Why this is safe here but we did *not* do it for `PR CI`:** `TestFlight` is not
a required status check, so skipping a docs-only merge has no side effect. `PR CI`
*is* required — skipping it would leave a docs-only PR with an unreported required
check and **block** the merge (see `docs/dev-workflow.md`). So: skip on
`TestFlight`, always-run on `PR CI` (a 3-min unit-test build is cheap and keeps
the gate clean).

> Verify the picker's semantics when you set it: the intent is "skip only when
> **all** changed files are within the excluded folders." Sanity-check that a
> docs-only merge is skipped and a code merge still builds.

## Gotcha — ITMS-90626: App Intent strings must not contain "apple"

Hit for real on the #29 spike (2026-07-23): the archive built and uploaded, then
App Store Connect **delivery validation** rejected it — *"Invalid Siri Support —
App Intent description ... cannot contain 'apple'"* — because an
`IntentDescription` said "Apple Music". Any App Intents-visible string (intent
`title`, `IntentDescription`, App Shortcut phrases) with "apple" in it bounces
the upload. Info.plist permission strings are unaffected. Symptom profile: **the
workflow runs green in Xcode Cloud but no build appears in TestFlight**, and the
failure arrives by email — check the email/App Store Connect delivery log before
suspecting start conditions.

## Gotcha — first-upload build number

Slice 0 already uploaded a manual build under version **1.0**. If the first
Xcode-Cloud build number happens to collide with (or be lower than) that manual
build, App Store Connect rejects it. If that happens, bump **`MARKETING_VERSION`**
(e.g. `1.0` → `1.0.1`) in the app target and merge — a new version train sidesteps
any build-number overlap. This is a one-time nuisance, not a recurring one.
