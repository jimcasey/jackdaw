# Jackdaw v1 — Walking-Skeleton Build Order

> **Status:** Ratified by owner (2026-07-14) and reconciled with the design-lead's
> plan. Stack decisions accepted as ADR 0002 (target) and ADR 0003 (persistence).
> **Date:** 2026-07-14. **Governs:** the order in which v1 is built, so platform
> risk is retired before feature work. This is a *sequencing* doc; it does not
> redefine scope (`docs/prd/mvp-scope.md`) or the export decision
> (`docs/adr/0001-obsidian-write-mechanism.md`).
>
> **App shell (owner-confirmed navigation):** v1 is a **two-tab tab bar —
> `Capture | Triage`** (design-lead). The skeleton and every slice build toward
> that shell: Slice 0 can stub it, capture work lands under the Capture tab,
> triage/export under the Triage tab. Recorded here so build order and design
> agree on the container.
>
> **De-risking rule (CLAUDE.md):** for a web engineer new to iOS, the risk lives
> in the *toolchain* (signing, provisioning, TestFlight, review) and in a small
> number of *platform unknowns* — not in writing views. So we build a thin
> end-to-end skeleton that ships to a real device first, retire the single
> highest platform unknown next, and only then build features — each as its own
> shippable end-to-end slice down the Capture → Triage → Export funnel.

---

## The sequence at a glance

> **REVISED 2026-07-14 (two owner decisions).** (1) **Nav pivot** — drop the two-tab
> shell → **Triage is the app root; Capture is a modal sheet auto-presented on
> launch** (ADR 0004). (2) **External capture is DEFERRED ENTIRELY from v1**
> (ADR 0005): a no-launch App Intent **cannot** get a precise GPS fix under
> When-In-Use, so external captures would be timestamp-only — value unjustified
> before the core loop is proven. The shared **`CaptureService` seam is still built
> in v1** as in-app capture's own core (ready for the fast-follow); **no external
> surface ships in v1.** Feasibility: `docs/feasibility/external-capture-precise-gps.md`.

### v1 slice sequence (final)

| # | Slice | Risk it retires | Status |
|---|-------|-----------------|--------|
| **0** | **Walking skeleton** — near-empty app, TestFlight → device | Signing, provisioning, TestFlight, on-device install | ✅ DONE |
| **1** | **Proof-point #1** — writable-bookmark write+verify | Highest architectural unknown; ratified **T2** | ✅ DONE |
| **2** | **In-app Capture sheet + Triage-root + SwiftData** (incl. the `CaptureService` seam) | Persistence store; nav flip (Triage root + auto Capture sheet, ADR 0004); autosave capture; the shared in-app capture core | ▶ in progress (reshaped) |
| **3** | **Real Triage** — inbox list + swipe Keep/Snooze/Discard + note editor | Retention state machine early states (incl. *kept-but-no-destination*); triage loop; discard-undo fork settled | Next |
| **4** | **Location context** — precise GPS (in-app) | When-In-Use entitlement, precise/coarse toggle, denied behavior, async backfill onto the live in-app draft | — |
| **5** | **Apple Notes export** (intermediate milestone, not shipped; kept) | Serializer + retention state machine *above* the seam; proves `ExportDestination` has two real adapters | — |
| **6** | **Obsidian export** — real v1 destination | Full hold-until-confirmed on the Slice-1 write path; lazy vault setup at first Keep; stale-bookmark re-grant | — v1 complete |

Each row is a vertical slice: it builds, installs on the owner's iPhone via
TestFlight, and does one thing end-to-end. We do not move to the next slice until
the current one is green.

### Fast-follow / v1.x (NOT in v1)

- **External capture surfaces** (Action button, Shortcuts, Control Center, Siri,
  widget, Lock Screen) via a `CaptureNoteIntent` front-end over the **same
  `CaptureService`** built in Slice 2. Deferred per **ADR 0005**. When built:
  - a thin one-shot-commit front-end (text via `@Parameter`/`requestValueDialog`),
    sharing SwiftData through a shared `AppModelContainer`;
  - **timestamp-only** by the platform GPS constraint — a foregrounding
    (`openAppWhenRun = true`) variant or a last-known-location cache are the only
    routes to external location, both fast-follow spikes;
  - enables the **ADR 0004 endgame**: once external surfaces seed the inbox, the
    Capture sheet stops auto-presenting → bare Triage-root.

> **Sequencing note (what shifted from the pre-defer draft):** the external-capture
> validation slice is **removed from v1** (→ fast-follow). Location returns to its
> natural spot right after Triage (Slice 4), now **in-app precise GPS only** — no
> external dimension to build. The `CaptureService` seam stays **inside Slice 2** as
> in-app architecture. Pre-pivot order (2 capture → 3 location → 4 triage → 5 Apple
> Notes → 6 Obsidian) is otherwise restored, with capture reshaped to the sheet nav.

### What of the existing Slice 2 code survives the nav flip

- **Survives unchanged:** the `Note` `@Model`; `.modelContainer` app wiring; the
  `CaptureViewModel` autosave logic (`edit`/`finishEditing`/`draft`); the
  `TextEditor`/placeholder/focus capture UI; the in-memory Swift Testing approach.
- **New in Slice 2 (kept for v1):** the shared **`CaptureService`** core (Note
  construction + SwiftData persistence + best-effort location; no SwiftUI/AppIntents
  imports) — built as the in-app capture's own core per ADR 0005, ready for the
  fast-follow external front-end. (`.modelContainer` will move to a shared
  `AppModelContainer.shared` only *when* the external intent is built in v1.x.)
- **Changes:** `RootView` — `TabView(Capture|Triage)` → a **Triage-root** view with
  `.sheet(isPresented:)` **auto-presenting** `CaptureView` on launch. `CaptureView`
  becomes **sheet content** (gains a grabber/dismiss; the sheet owns its keyboard).
  The former `TriageStubView` becomes the **Triage root list** (still read-only
  until the real-Triage slice), not a tab.
- **Moot / removed:** the keyboard-covers-floating-tab-bar wrinkle and any
  "Done-button to reveal the tab bar" handling — **gone by construction**, because a
  sheet owns its keyboard and dismissal (swipe-down dismisses the sheet → reveals
  Triage).
- **Better, as a side effect:** the earlier **`.onDisappear` prune-trigger
  reliability risk disappears** — "leaving Capture" is now the **sheet's `onDismiss`
  callback** (a single well-defined event) plus `scenePhase == .background`. More
  deterministic than TabView tab-switch `.onDisappear`.

---

> **Numbering note for the detailed sections below.** The at-a-glance table above
> is authoritative for the **final v1 order**. The detailed per-slice write-ups that
> follow predate the renumber and retain their original headings — map them as:
> detailed **"Slice 3 — Location"** = final **Slice 4** (now in-app precise GPS
> only); detailed **"Slice 4 — Triage"** = final **Slice 3**. Capture (final Slice 2)
> now uses the sheet nav (ADR 0004) — see `docs/slices/slice-2-capture-swiftdata.md`.
> Apple Notes (5) and Obsidian (6) are unchanged. Substance in those sections
> (state machine, entitlement work, export) stands; only the numbers/nav shifted.

## Prerequisite — Apple Developer Program enrollment

Before Slice 0 can exist as described, the owner must be enrolled in the paid
**Apple Developer Program** (~$99/yr). This is the toolchain reality a web
engineer would not anticipate:

- A **free** Apple ID lets you side-load to your own device, but provisioning
  profiles expire after **7 days** and **TestFlight is not available**.
- **TestFlight requires the paid program.** Since our whole de-risking strategy
  is "ship to a real device via TestFlight early," this is a hard gate on Slice 0.

Flagging it here so it is not discovered mid-skeleton.

---

## Slice 0 — The walking skeleton (toolchain slice)

**Goal:** exercise the *entire real deployment path* while the app does almost
nothing, so that every later slice iterates against a known-good pipeline.

**What "does almost nothing" contains, concretely:**
- One SwiftUI screen showing the app name and the **build number / version
  string** (so we can confirm on the phone *which* build is installed — this is
  the one non-trivial requirement; everything else is chrome).
- No capture, no location, no persistence, no vault, no export. Optionally a
  single button that flips a label, purely to prove touch input renders.

**The pipeline this actually retires** (the point of the slice):
1. Create the Xcode project; set bundle identifier and the **min deployment
   target** (see Stack ADR A below — load-bearing *here*).
2. Wire **signing & provisioning**: development team, signing certificate,
   provisioning profile. This is the step with the highest "unknown unknowns"
   for someone who has never done it.
3. **Archive** the app and upload to **App Store Connect**.
4. Distribute via **TestFlight internal testing** and **install on the owner's
   physical iPhone**, then launch it.

**Why internal TestFlight, and what it does *not* retire:**
- **Internal** TestFlight testing (your own team, up to 100 testers) has **no
  Beta App Review** — zero review delay. That is exactly what we want to get a
  build onto the device fast. ([Apple — TestFlight](https://developer.apple.com/testflight/))
- It does **not** retire full **App Store review**. That risk is only retired at
  real submission. For a **single-user personal tool**, the honest question is
  whether Jackdaw ever goes to the App Store at all, or whether **TestFlight is
  the permanent distribution channel**. Note: every TestFlight build stops being
  installable after **90 days**, so a TestFlight-forever strategy means periodic
  re-uploads. **This is an owner decision** — I recommend deferring App Store
  submission indefinitely and treating TestFlight as the delivery channel for a
  single-user app; revisit only if distribution goals change.

**Done when:** the owner opens Jackdaw on their iPhone, installed via TestFlight,
and sees the build number. The pipeline is now a repeatable tool, not an unknown.

---

## Slice 1 — Proof-point #1: writable-bookmark write + verify

> This is **ADR 0001 verification gate 2(a)**, and it is the earliest feature-ish
> slice deliberately: it is the **single highest-risk architectural unknown** in
> the whole project. A failure here forces a topology change (T2 → T1) that moves
> where the vault lives — we want that answer *before* building export UX on top
> of an assumption. It comes as early as the toolchain (Slice 0) allows.

**The slice (a debug harness, not real UX):**
1. A button: *Pick vault folder* → present `UIDocumentPickerViewController` in
   `.folder` mode → user selects the Obsidian vault folder
   (`On My iPhone/Obsidian/<vault>` under the recommended T2 topology).
2. Persist a **security-scoped bookmark** to that folder
   (`url.bookmarkData()` — default options; **not** the macOS-only
   `.withSecurityScope`, which is a real trap on iOS).
3. **Cold-relaunch the app** (fully quit and reopen — this is the part that
   proves *persistence* across launches, not just same-session access).
4. Resolve the bookmark; handle `bookmarkDataIsStale` (re-create if stale);
   call `startAccessingSecurityScopedResource()`.
5. Write a `.md` file into the folder via **`NSFileCoordinator`** (another
   process — iCloud / Obsidian Sync — may touch the folder concurrently), then
   **read the bytes back and verify** they match. Pair with
   `stopAccessingSecurityScopedResource()`.
6. Show a pass/fail result label with the verified content.

**Run location:** **physical device via TestFlight.** The simulator does not
faithfully reproduce the document picker's grant semantics, the real Obsidian
container, or Obsidian Sync — this proof point is meaningless off-device.

**PASS looks like:** after a cold relaunch, the bookmark resolves (non-stale, or
stale-then-successfully-recreated), the write succeeds, the read-back matches,
**and** the file surfaces in Obsidian on the phone (gate 2b was already confirmed
by hand-dropping a file; this proves the *app's own write* does the same).

**FAIL looks like:** the picker does not grant persistently *writable* access
into the container, the resolved bookmark cannot write (permission/throw), or
Obsidian ignores the app-written file. **A fail triggers the ADR's T1 fallback:**
relocate the vault to the iCloud `Obsidian/<vault>` folder and re-run this slice
there (accepting iCloud's flakier sync). Git (Option D) is only considered if T1
also fails. See ADR 0001 §"Verification gates" gate 3.

**Where the bookmark is stored:** a single `Data` blob — a file in the app
container or `UserDefaults` is fine. This does **not** require the main
persistence store, so the persistence ADR (Stack ADR B) is **not** yet
load-bearing here.

**Design dependency:** none for this harness. The *real* first-run "pick your
vault folder" setup screen and the "we lost access, re-grant" recovery flow are
**design-lead's**, and become load-bearing at Slice 6 (see there).

---

## Slice 2 — Thin capture (text + timestamp)

**The slice:** a capture screen (under the **Capture** tab) — text field + Save.
On save, attach a **timestamp** and persist the note to a **local, offline
queue**; show captured notes in a plain list. No location yet (isolated to Slice 3
to keep the permission risk in its own slice). No triage actions yet.

**Seam contract established here (Talon / design-lead requirement):** capture
**persists the note first, synchronously**, and never blocks on anything slow.
This slice bakes that in with just text + timestamp; Slice 3 extends it by
backfilling location *asynchronously after* the note is already saved.

**Risk retired:** first real **persistence store** and offline capture. This is
where **Stack ADR B (persistence) becomes load-bearing** — we now need to store a
growing collection of structured, mutable records that survive relaunch. Ratify
that ADR before starting this slice.

**Done when:** type text, save, kill the app, relaunch — the note is still there.

---

## Slice 3 — Location context (precise-GPS entitlement)

**The slice:** attach **precise (GPS) location** to a captured note. This is a
self-contained slice specifically because the **entitlement/permission work is
its own platform risk**, separate from persistence.

**Capture-before-GPS contract (Talon / design-lead requirement, load-bearing
here):** the note is **persisted at Save with no location**, then the GPS fix is
resolved **asynchronously and backfilled** onto the saved note when it arrives.
Capture must never wait on a location fix (a GPS lock can take seconds, or never
come indoors/offline). A note may therefore legitimately exist with a *pending*
or *absent* location — the triage edit path (Slice 4) lets the owner see/correct
it. This is why Slice 2 persists first and Slice 3 only enriches.

**The entitlement work (tech-lead owns correctness; design-lead owns the flow):**
- **Info.plist usage strings.** iOS *requires* a purpose string or the app
  crashes on the permission request. For location this is
  `NSLocationWhenInUseUsageDescription` (Jackdaw only needs location *while the
  user is capturing*, i.e. **When-In-Use**, never Always/background — a smaller,
  more defensible privacy ask).
- **Precise vs. coarse toggle.** Since iOS 14, the user can grant **approximate**
  location even when the app asks for precise. The PRD settled on **precise
  (GPS)**. Handle it correctly: check `CLLocationManager.accuracyAuthorization`;
  if the user granted `.reducedAccuracy`, we can request temporary full accuracy
  for a single capture via `requestTemporaryFullAccuracyAuthorization`, but must
  **degrade gracefully** if refused. Add the
  `NSLocationTemporaryUsageDescriptionDictionary` purpose key if we use temporary
  full-accuracy requests.
- **Permission-denied behavior (graceful).** If the user denies location, or
  grants reduced accuracy and declines the upgrade, **capture must still
  succeed** — the note saves with timestamp and *no* (or coarse) location, never
  blocking the core "get the thought out" job. Capture is the sacred path;
  location is enrichment. We surface the missing/reduced context at triage
  (editable there per the PRD), rather than gating capture on a permission.

**Design dependency:** the **location permission rationale + prompt flow** is
design-lead's (they are already working it, per the PRD's precise-location
dependency). Tech-lead guarantees the entitlement plumbing and the denied-path
behavior; design decides *when/how* we ask.

**Done when:** a captured note carries a precise coordinate on a device that
granted permission, and captures still succeed cleanly on a device that denied
it.

---

## Slice 4 — Triage (batch inbox)

**The slice:** a **batch inbox** list of un-triaged notes (under the **Triage**
tab). Per note: **Discard**, **Snooze**, **Keep**. Per note: **edit the note
text** and **edit/correct the attached context** (per PRD JTBD 3). No export yet —
Keep just advances a note into the retention machine.

**Risk retired:** the **retention state machine** and the triage loop that drives
the inbox toward empty (PRD success criterion 2). Building the machine here,
before export, means the export slices only wire the destination onto states that
already exist.

**State machine — reconciled with the lazy-setup decision (owner-ratified).**
Because vault setup is now **lazy** (triggered at the first Keep, not a first-run
gate — see Slice 6), a note can be **Kept before any destination is configured**.
That is a **valid pending sub-state, not an error**:

```
captured → kept → pending → writing → confirmed → deleted
                    ▲  │
      (no destination yet = a legitimate pending reason,
       not a failure — the note simply waits for setup)
```

- `kept` transitions to `pending`. `pending` carries a **reason** (see the seam
  contract below); "no destination configured yet" is one such reason and must be
  presented as *awaiting setup*, never as a failed export.
- `discarded` and `snoozed` are the other terminal/deferred branches off triage.

**Talon seam contracts the state machine must satisfy (design-lead surfaced;
these are hard requirements on the layer *above* `ExportDestination`):**
1. **Per-note failure reason is first-class.** `pending`/failed state must expose
   *why*, distinguishing at minimum: **offline**, **access-lost** (stale/invalid
   bookmark), **write-error**, and **no-destination-yet**. The UI keys off this to
   offer the *right* recovery — **Retry** (offline / write-error) vs **Re-grant**
   (access-lost) vs **Set up vault** (no-destination-yet). A single opaque "failed"
   is insufficient.
2. **The retention layer exposes, per note: current state + failure reason;** and
   in aggregate: **a count** of notes not yet exported; plus a **retry /
   return-to-inbox affordance** per note (so a stuck note can be retried or sent
   back to triage). This is what lets the owner keep the funnel "empty and honest"
   (PRD success criterion 4). Design-lead owns the surfacing UI; this slice owns
   the state + API it reads.

**Design dependency:** **Snooze "session" definition** (PRD §7.2) — what
starts/ends a session determines when snoozed notes reappear. Build with `snoozed`
as a state and the *reappear trigger* injected, so a late design decision does not
block this slice; the trigger must be settled before Snooze is trustworthy daily.

**Deferred tech↔design fork — settle at this slice, not before:** the
**discard-undo banner** (a brief "Undo" affordance after Discard). Design-lead
wants it (safety net against a mis-tap deleting a thought); tech-lead resisted it
as friction/complexity against the funnel's fast keep-kill rhythm. **Owner has not
yet ruled.** It only becomes concrete when Discard is built (here), so it is
parked as an open call to resolve at Slice 4 — noted so it is not lost.

**Done when:** the owner can run a triage pass and empty the inbox; Kept notes
enter `pending` (with a correct reason, including *awaiting setup*) and survive
relaunch; Snoozed notes leave and return per the (design) session rule.

---

## Slice 5 — Apple Notes export (intermediate de-risking milestone)

> **Not a shipped v1 destination** (PRD non-goal, explicit). A **build-order
> device** sanctioned by owner arbitration. Its job here is to de-risk *the
> export pipeline above the `ExportDestination` seam*, decoupled from the
> bookmark/coordinator plumbing.

**The slice:** build, behind the `ExportDestination` protocol (subsystem *Talon*):
- The **note serializer** — markdown body + **YAML frontmatter** (timestamp +
  precise GPS). Reused verbatim by the Obsidian adapter.
- The **retention state machine tail** — `kept → pending → writing → confirmed →
  deleted`, deleting **only** on `confirmed`, returning to `pending` on any
  failure. Reused verbatim.
- An **`AppleNotesDestination`** adapter using **Share Sheet** plumbing
  (`UIActivityViewController`) — the only practical Apple Notes write path, since
  Apple Notes has no clean write API.
- **Batch export UX** (export the Kept set in one action) — the funnel's "clear
  the inbox" ethos.

**Honest caveat, stated up front:** the Share Sheet **cannot truly confirm** a
write (ADR 0001, Candidate A). So for *this milestone only*, `confirmed` is
**degraded** — we treat share-sheet completion as confirm. That is fine because
the milestone's purpose is to exercise the **pipeline wiring and the seam**, not
to be a trustworthy retention path. Apple Notes is scaffolding.

**Why this earns its place — and the tension I want the owner to see:**
Proof-point #1 (Slice 1) already front-loaded and retired the *Obsidian write
mechanism* risk. That **weakens** the original rationale for Apple Notes ("prove
the loop before Obsidian is solved"), since we solved the hard write bit early.
What Apple Notes still buys us:
1. It de-risks **everything above the seam** (serializer, state machine, retry,
   batch UX) against a trivial destination, *before* we wire the Obsidian
   adapter's stale-bookmark / coordinator / re-grant complexity.
2. Standing up **two real adapters** behind `ExportDestination` is the best
   possible proof the seam is *actually* clean and not hard-wired — directly
   serving the PRD's "clean internal boundaries only" stance.
3. It yields a shippable, end-to-end funnel while design-lead finishes the
   Obsidian first-run setup + re-grant recovery UX (a Slice-6 dependency).

**Owner call — RESOLVED (2026-07-14): Slice 5 is KEPT.** The tech-lead lean
("keep it — cheap relative to the confidence it buys, and it validates the seam")
was confirmed by the owner. It remains the most cuttable slice if the timeline
later needs compressing, but it is in the plan as ratified.

**Done when:** Keep a note in triage → batch export → it lands in Apple Notes with
frontmatter, and the app **forgets** it (funnel closes end-to-end).

---

## Slice 6 — Obsidian export (real v1 destination)

**The slice:** swap in the **`ObsidianDestination`** adapter behind the same seam.
Reuse the **serializer + state machine from Slice 5** verbatim; reuse the
**bookmark/folder-write proven in Slice 1**. Wire full **hold-until-sync-confirmed
retention**: `kept → pending → writing → confirmed` via **write-then-read-back
verify** into the vault folder, then `deleted`. Handle **stale bookmark →
re-grant** recovery. Batch export.

**Vault setup is LAZY, not a first-run gate (owner-ratified 2026-07-14 —
design-lead's position, over the tech-lead's).** The "pick your vault folder"
document-picker + bookmark persistence fires **at the first Keep that needs a
destination**, *not* as a first-run onboarding wall. Consequences absorbed into
the plan:
- **Zero-friction first capture is protected** — the owner can install, capture,
  and triage without ever confronting a vault-setup screen. This was the deciding
  reason; accepted **at the cost of one more state**.
- **The "kept-but-no-destination" state is now real** and is handled in the Slice 4
  state machine as a legitimate `pending` reason (*no-destination-yet / awaiting
  setup*), never an error. When the first Keep occurs with no vault configured,
  the export path triggers the setup pick; once the bookmark exists, those waiting
  notes drain from `pending` into `writing`.
- **Accepted tradeoff, stated plainly:** lazy setup trades a slightly more complex
  retention model (one extra sub-state + its UI treatment) for a friction-free
  first run. The tech-lead had argued for an explicit first-run setup to keep the
  state machine simpler; the owner ruled for lazy setup. Recorded so it is not
  relitigated.

**Design dependencies (all design-lead, all load-bearing *here*):**
- **Lazy vault-folder setup at first Keep** — the "pick your vault folder" pick,
  invoked from the export path rather than onboarding. (Slice 1 exercised the
  *mechanism* in a debug harness; this is the user-facing, lazily-triggered
  setup.)
- **Re-grant recovery UX** — when a bookmark goes stale (OS update, vault moved),
  gracefully prompt to re-pick the folder rather than failing silently. ADR 0001
  marks this "required, not optional." Maps to the state machine's **access-lost**
  reason → **Re-grant** affordance (Slice 4 contract).
- **Pending / failed-export surfacing** — the owner must *see* per-note state, the
  not-yet-exported **count**, and act via **Retry / Re-grant / Set up vault /
  return-to-inbox** as the reason dictates, or the "funnel stays empty and honest"
  criterion silently breaks. This consumes the Slice 4 seam contract directly.

**Done when:** Keep → (first time) pick the vault → the note is verified into the
vault, deletes from Jackdaw, and appears in Obsidian on both devices (via Obsidian
Sync under T2); subsequent Keeps export without a setup prompt. **This is v1
feature-complete.**

---

## Stack decisions — RATIFIED (ADR 0002, ADR 0003)

Both TBD stack items are now **decided and written as ADRs** (owner-ratified
2026-07-14). This section records when each is load-bearing and the reasoning; the
ADRs are authoritative.

- **ADR 0002 — Min iOS target = iOS 26** (`docs/adr/0002-min-ios-deployment-target.md`).
- **ADR 0003 — Persistence = SwiftData** (`docs/adr/0003-persistence-swiftdata.md`).

### ADR 0002 — Minimum iOS deployment target = iOS 26 (Accepted)

**Load-bearing at:** **Slice 0** (you must choose a deployment target the moment
you create the Xcode project; it gates every API you can call thereafter).
**Set at Slice 0.**

**Decision: target iOS 26** (fall back to iOS 18 only if some tool in the chain
lags). Reasoning, for an owner new to iOS:
- On iOS, the **deployment target** is the *oldest* OS the app will run on. A
  *lower* target = more devices supported but *fewer* APIs available (newer APIs
  are gated behind `@available` checks and you must write fallbacks). A *higher*
  target = you can call modern APIs freely with no availability ceremony.
- Jackdaw is a **single-user app on the owner's own phone.** There is **no
  install base to support** — the usual reason to lower the target (reach older
  devices) simply does not apply. So we take the highest target the owner's
  device runs, and buy the cleanest, most modern API surface.
- As of 2026-07 the current iOS is **26.x** (Apple renumbered from iOS 18
  straight to iOS 26 in 2025 to align OS names with the year; iOS 27 ships fall
  2026). Targeting 26 means SwiftData at its most mature and no availability
  gymnastics. ([Apple security releases](https://support.apple.com/en-us/100100),
  [iOS 26 — Wikipedia](https://en.wikipedia.org/wiki/IOS_26))

**Direction note:** raising the target later is free; *lowering* it would strand
APIs we relied on — so we deliberately chose the easy-to-relax direction. Full
reasoning in ADR 0002.

### ADR 0003 — Persistence = SwiftData (Accepted)

**Load-bearing at:** **Slice 2** (first time we persist a growing collection of
structured, mutable records across launches). **Not** needed for Slice 0 or
Slice 1 (the bookmark is a single blob — a file or `UserDefaults` suffices), so
this decision only bites at capture. Depends on ADR 0002 for the iOS 17+ floor.

**Decision: SwiftData.** Reasoning, for an owner new to iOS but fluent from
web:
- **What our data actually is:** a modest, single-device collection of note
  records with a **lifecycle/state machine** (`captured → kept/snoozed/discarded
  → pending → … → deleted`), queried for the inbox, mutated at triage. That is
  "small relational store with observation," not "key-value blob."
- **`UserDefaults` is disqualified** — it is for small preference values, not
  collections of records with lifecycle. Wrong tool.
- **Files (e.g. JSON/Codable on disk)** would work given low volume, but you
  hand-roll querying, change-observation, and migration. Viable but you rebuild
  what a store gives you.
- **Core Data** is the mature, battle-tested option, but its API is heavier and
  more ceremony than we need, and it does not integrate as naturally with
  SwiftUI.
- **SwiftData** is the **SwiftUI-native** path and the one closest to what a web
  engineer expects: you declare a model with the `@Model` macro (think an ORM
  entity), and SwiftUI views observe it with `@Query` (think a live,
  auto-updating query binding — analogous to a reactive data hook). It integrates
  with the MVVM/SwiftUI default we already set, minimizes boilerplate, and — with
  Stack ADR A at iOS 26 — we get it at its most mature (it shipped in iOS 17 and
  has hardened since; **it hard-requires iOS 17+**, which is the concrete
  coupling to ADR A).
  ([SwiftLee — SwiftData min version](https://www.avanderlee.com/workflow/minimum-ios-version/))
- **Coupling to ADR 0002, stated explicitly:** choosing SwiftData sets a **floor
  of iOS 17** on the deployment target. The iOS 26 target (ADR 0002) clears that
  floor with room to spare, so the two decisions are consistent — 0002 is the
  prerequisite of 0003.

---

## Where this plan meets the design-lead's plan (dependencies to watch)

| This build order needs… | …from design-lead | By slice |
|---|---|---|
| Two-tab `Capture \| Triage` shell | App navigation (confirmed) | Slice 0 stub → grows through slices |
| A location permission rationale + prompt flow | Location permission flow | Slice 3 |
| A settled Snooze **session** trigger | Snooze rhythm / session definition | Slice 4 (buildable earlier with the trigger injected) |
| **Lazy vault-folder setup** at first Keep (not first-run) | Vault setup flow, invoked from export | Slice 6 |
| **Re-grant recovery** on stale bookmark → maps to `access-lost` reason | Re-grant recovery UX | Slice 6 |
| **Pending / failed** surfacing: per-note state + reason + count + Retry/Re-grant/Set-up/return-to-inbox | Pending/failed-export surfacing (consumes the Slice 4 seam contract) | Slice 4 (state/API) → Slice 6 (Obsidian reasons) |

## Open calls and settled tensions

**Settled by owner arbitration (2026-07-14):**
- **Vault setup = lazy at first Keep** (design-lead's position, over tech-lead's
  first-run-gate preference). Absorbed: the *kept-but-no-destination* pending
  sub-state (Slice 4) and lazy setup trigger (Slice 6). Accepted tradeoff — one
  extra state for a friction-free first run.
- **Slice 5 (Apple Notes) kept** — tech-lead lean confirmed.
- **Navigation = two-tab `Capture | Triage`.**
- **Stack: iOS 26 target (ADR 0002) + SwiftData (ADR 0003).**

**Still open — flagged for a later owner call (do not resolve now):**
- **Discard-undo banner** (Slice 4). Design-lead wants it (mis-tap safety net);
  tech-lead resisted (friction/complexity vs. the fast keep-kill rhythm). Deferred
  to **settle when Discard is built at Slice 4**, since it only becomes concrete
  there.
- **App Store vs. TestFlight-forever** (Slice 0 note). For a single-user tool I
  recommend deferring App Store submission indefinitely (TestFlight, with its
  90-day re-upload cadence, as the delivery channel). Not urgent; revisit only if
  distribution goals change.

**Residual note (not a blocker):** capture is usable in the wild by Slice 3; the
funnel only *closes* at export (Slice 6). If the product-lead wants captured
value sooner, that is already satisfied — the ordering does not delay capture,
only the export tail, which depends on the Slice 4 state machine for correctness.

---

## Related
- Scope: `docs/prd/mvp-scope.md`
- Export decision + verification gates: `docs/adr/0001-obsidian-write-mechanism.md`
- Concept seed: `docs/prd/concept-brief.md`
