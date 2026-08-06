# Learnings from the prototype

**Status: filled in 2026-08-06** (issue #1). The spike at `~/Code/jackdaw-spike`
([jimcasey/jackdaw-spike](https://github.com/jimcasey/jackdaw-spike)) reached
TestFlight with the full v1 funnel working on-device, plus two slices of its
v1.x "capture wave." This doc re-examines what it learned against the new scope
— triage cut, capture and export kept, tagging redesigned — and gives each
learning a verdict:

- **Promote** — still true and still in scope; carried forward via an ADR or
  persona memory, each in its own PR (follow-ups: the issues named per section).
- **Drop** — was about triage or the machinery built on it; doesn't survive the
  cut.
- **Re-open** — decided for the old scope; needs a fresh decision here, with the
  spike's reasoning as evidence rather than precedent.

Source paths below are relative to the spike repo. Nothing is inherited by
default; a promote is a deliberate act.

---

## 1. Usage evidence (owner, recorded 2026-08-06)

The spike was in real use on the owner's iPhone from mid-July 2026 (Slice 0
shipped 2026-07-14) to early August — v1 complete (slices 0–7), then wave
slices A (external capture skeleton, on-device 2026-07-25) and B (note types,
merged 2026-08-05). What actually happened in the field:

- **Volume: 5–15 captures/week** — steady, habitual use, roughly one or two a
  day across ~3 weeks. The spike's own success bar ("still in weekly use after
  ~4 weeks," `docs/prd/mvp-scope.md` §6.5) was on track to be met when work
  stopped for the restart.
- **Entry points used: the in-app capture sheet and Siri/Shortcuts.** Nothing
  else stuck.
- **Entry points unused:** the **Action button** — configured 2026-07-25
  precisely to run the spike's own two-week adoption experiment — **never
  became habit**. Not prompt friction, not the missing context on external
  captures; the owner simply never reached for it. That concludes the
  experiment ADR 0008 left open: in-app capture remained dominant. The typed
  **Listening shortcut** merged only 2026-08-05, too late to accumulate any
  evidence.
- **Inbox behavior: too little volume to tell** whether it drained or grew.
  At one-to-two notes a day, triage never faced a real pile.
- **The junk filter did no real work.** The owner **kept everything by
  default** — swiped Keep without judging. Keep/kill was ceremony at this
  volume, not filtering.
- **And the vault stayed clean anyway.** Despite everything being kept, nothing
  landed in Obsidian that the owner later wished hadn't.
- **Field failures: exactly one.** The 2026-07-21 silent-export incident
  (spike `docs/STATUS.md` field notes, spike issue #25): kept notes silently
  stuck in-app, nothing written, **no failure surface and no success signal**
  — the confirmation toast had a rendering bug, and the stuck notes traced to
  a vault-folder setup mismatch, drained by a manual rename + Retry. The exact
  first-pass trigger was never reproduced. Nothing else failed in ~3 weeks:
  no permission problems, no missing context, no further export trouble.

### What the evidence means for the restart

1. **The triage cut is vindicated by the best data this project will ever
   have.** The stage's one irreplaceable job — keeping junk out of the vault —
   turned out not to exist: keep/kill filtered nothing, and the vault stayed
   clean regardless. Cutting triage removes ceremony, not protection.
2. **The "fail loudly" rule is validated from the failure side.** The only real
   field failure was export failing *silently* — protected by
   hold-until-confirmed, but invisible. What fixed the experience was a loud,
   immediate signal (the "Saved to Obsidian" toast, added at owner direction,
   reversing an earlier "success stays silent" call — no toast = nothing
   landed). The restart's export design should treat signal, not queue
   machinery, as the safety feature.
3. **External capture surfaces are not automatic wins.** The hardware-fast path
   (Action button) lost to Siri and just opening the app. Surface work should
   follow demonstrated pull, not platform capability.
4. **Caveats.** One user, one device, ~3 weeks, low volume. "Inbox drained vs
   grew" was never tested; neither was tagging desire (slice B barely shipped).
   #2's success criteria should inherit the *shape* of this evidence (owner
   behavior, not metrics) and the 5–15/week baseline to beat.

---

## 2. Verdict summary

| Area | Verdict | Detail | Feeds |
|---|---|---|---|
| Export write mechanism (folder write, bookmark, verify) | **Promote** | §3 | #4 |
| Note serializer + frontmatter contract | **Promote** (contract details re-open with tagging) | §3 | #4, #3 |
| Retention state machine + outbox surfacing | **Re-open** (collides with the simplicity rule) | §3 | #4 |
| Capture model (autosave, prune, fresh-note re-entry) | **Promote** | §4 | #2, #15 |
| Ambient context: location mechanics + permission UX | **Promote** (whether v1 attaches location: open) | §5 | #12 |
| Ambient context: now-playing / media | **Re-open** | §5 | #2 |
| Classification / type system (ADR 0007) | **Re-open** — evidence, not a design to copy | §6 | #3 |
| Navigation model (triage-root, ADR 0004) | **Drop**; re-derive from capture-first | §7 | #2 |
| Triage machinery (keep/kill, snooze, undo, editor) | **Drop** (six embedded patterns promote) | §7 | #15 |
| External capture surfaces & two-lane architecture | **Re-open** (platform facts promote) | §8 | #2, #15 |
| Stack: min iOS target = 26 | **Promote** via its ADR | §9 | #5 |
| Stack: SwiftData | **Re-open** (facts promote as input) | §9 | #6 |
| MVVM ↔ SwiftData split; Xcode project facts | **Promote** | §9 | #15, #7 |
| CI/TestFlight: ADR 0006 + runbook + gotchas | **Promote** — handed to #9 explicitly | §10 | #9 |
| Process disciplines & a11y baseline | **Promote** | §11 | #15 |
| Product identity (naming mechanics) | **Promote** | §11 | #15 |

Every promote has a home: existing decision issues (#4, #5, #9, #12), the
persona-memory issue (#15), or the PRD (#2). Nothing promotes by bulk copy.

---

## 3. Export — the strongest promote, with one seam re-opened

The spike's export subsystem (codename *Talon*) is the most valuable artifact
it produced, **and** the place where the old scope is most baked in. Split it:

### Promote: the write mechanism (→ #4)

Source: `docs/adr/0001-obsidian-write-mechanism.md`, `docs/slices/slice-1-vault-bookmark.md`,
tech-lead memory `decision-obsidian-write.md`, `slice-1-spec.md`.

- **Direct folder write into the Obsidian vault via a persisted security-scoped
  bookmark**, proven on-device 2026-07-14 across a cold relaunch, with the
  vault local (`On My iPhone/Obsidian`) and Obsidian Sync propagating to the
  Mac (**topology T2**). Never run two sync engines on one vault.
- Why the alternatives lost — still true and worth not relitigating:
  `obsidian://` is fire-and-forget (no return channel, can't underwrite any
  confirmation model); the share sheet can't confirm the save and costs
  per-note taps; git push lands in the owner's *backup* remote, not the live
  sync path, and drags in libgit2 + credentials.
- The mechanics: SwiftUI `.fileImporter` with `[UTType.folder]`; create the
  bookmark with `options: []` (**`.withSecurityScope` is macOS-only — a real
  trap**); handle `bookmarkDataIsStale` by recreating; pair
  `start/stopAccessingSecurityScopedResource()`; all I/O through
  `NSFileCoordinator`; **write-then-read-back byte-for-byte verify**; no iOS
  entitlement or Info.plist string needed for user-picked folders; bookmark
  lives in `UserDefaults` (it's config, not a secret).
- **Capture has zero dependency on the vault** — you can capture for days
  before ever picking a folder. Keep that property.
- The on-device test protocol matters: a cold-relaunch check must *kill* the
  app from the switcher, not background it — a backgrounded app keeps the
  resolved URL in memory and false-passes.

### Promote: the serializer (→ #4; contract details interact with #3)

Source: `docs/slices/slice-6-apple-notes-export.md` (§ what survived it),
tech-lead memory `slice-6-apple-notes-spec.md`, ADR 0007 (contract v2).

- Pure, destination-agnostic `NoteSerializer`: YAML frontmatter + blank line +
  raw body; decoupled from SwiftData via a snapshot type; golden-tested.
- Hard-won formatting rules: ISO-8601 UTC `created`; coordinates via
  `String(format: "%.6f")` because **a comma-decimal locale would otherwise
  corrupt the YAML**; `place` always quoted/escaped; **omit-when-absent** —
  missing context is an omitted key, never an empty value.
- Filename `yyyy-MM-dd-HHmmss-<8-hex-of-id>.md`: sorts naturally in Obsidian,
  and the id suffix prevents two same-second notes from silently clobbering
  each other under an atomic write — real data loss otherwise.
- The frontmatter *contract* (which keys, and how tags land) is #3/#4's call —
  the spike's v2 contract is a starting point, not a constraint. Its one priced
  caveat carries: keys are additive-only; renaming an emitted value is
  breaking, and key-absence semantics (`WHERE !type`) break if you later emit
  a default.

### Re-open: retention, failure handling, and surfacing (→ #4)

Source: slices 6–7 specs, design-lead memory `export-status-surfaces.md`,
ADR 0001's retention section.

The spike's answer was **hold-until-sync-confirmed**: a note is deleted only
out of `confirmed` (`kept → pending → writing → confirmed → deleted`), any
failure returns it to `pending` with a typed reason
(`noVaultConfigured / accessLost / writeFailed / verifyMismatch`), `.writing`
persisted before the await so a mid-export kill is recoverable, no auto-retry,
counts-only surfacing via a reason-driven bottom bar. This was careful,
correct engineering — **and it is a durable outbox, the exact machinery the
restart's simplicity rule ("export directly, fail loudly") exists to
question.** Two triage assumptions are also baked in: the machine's entry
state is a human Keep decision, and its escape hatch for a permanently
failing note is "return to inbox" — a place that no longer exists.

What #4 must take from it rather than inherit:

- **The confirmation requirement is real.** "Bytes verified in the vault
  folder" vs "handed to iOS" is the distinction that made export trustworthy;
  whatever replaces the state machine still needs a true success signal.
- **State vs reason must stay separate fields.** A single opaque "failed" was
  explicitly found insufficient — the reason is what makes failure actionable
  (Retry vs Re-grant vs Set up vault).
- **The poison-note wedge is unsolved under the new rules.** The spike's
  checkpoint review found a permanently failing note wedges any retry surface;
  its fix was triage-shaped. The simplicity rule bans the queue that made the
  wedge visible — #4 must say what happens to that note instead.
- **Silent success was field-tested and rejected.** The in-the-moment signal
  (toast) doubled as the diagnostic. "Fail loudly" should be read as "signal
  loudly, both ways."
- The lazy vault setup pattern (never a first-run gate; the picker never fires
  from an automatic action, only a deliberate tap) promotes; its *trigger*
  ("first Keep") needs a new home in a keep-less flow.

`AppleNotesDestination` and the `ExportDestination` seam exist in the spike as
a documented second adapter; whether the restart keeps a destination seam at
all is #4's call.

---

## 4. Capture model — promote (→ #2 for ratification, #15 for memory)

Source: design-lead memory `capture-model.md`, `docs/design/capture-and-triage-flows.md`
§0–1, tech-lead memory `slice-2-spec.md`, `slice-5-location-spec.md`.

Owner-confirmed on the spike, field-proven for three weeks, and entirely
scope-independent:

- **Autosave-as-you-type; no Save/Done commit action.** Losing a fleeting
  thought is the worst failure mode; autosave makes it structurally
  impossible. (This overrode an explicit-save design — settled, don't
  relitigate.)
- **Lazy creation** on the first non-whitespace character; **prune-on-abandon**
  (an empty note is discarded on *leaving* capture — never mid-session);
  **leaving is the commit**, so no "discard changes?" dialog can exist.
- **Re-entry always opens a fresh empty note** — never resumes a prior one.
  This is the line that stops Capture drifting into a notepad, and it matters
  *more* here: with no triage editor, resuming past notes would be the only
  in-app editing surface, i.e. scope creep by convenience. Post-capture
  editing happens in the destination app — that's the scope reset's explicit
  rationale.
- **"New note"** as a keyboard-toolbar accessory for rapid multi-capture:
  banks the note, clears the field, keyboard stays up; light haptic + brief
  "Captured" micro-confirmation; its appearance doubles as the save signal.
  No per-keystroke saved indicator (noise, and VoiceOver spam).
- **Capture never waits on anything**: full-bleed `TextEditor` (placeholder is
  a `Text` overlay — there's no native one), focus set in `.task` (not
  `.onAppear`, which drops), keyboard up on arrival; note persisted before any
  GPS fix, context backfilled async with a `modelContext != nil` guard so a
  pruned note isn't resurrected; offline is a non-event by construction.
- Implementation posture: rely on SwiftData's main-context autosave for
  coalescing (don't `save()` per keystroke), one explicit save on
  `.background`; one owner of save cadence, never two.

One clause dies with triage: "continuing to edit a captured note happens in
Triage." The replacement is already decided by the scope reset — the
destination edits.

---

## 5. Ambient context — mechanics promote, scope re-opens

Source: `docs/slices/slice-5-location.md`, tech-lead memory
`slice-5-location-spec.md`, design-lead memory `location-permission.md`,
`docs/feasibility/external-capture-precise-gps.md`, ADR 0009.

### Location (→ #12 decides if v1 attaches it; mechanics promote via #15)

- Working, field-tested in-app: precise GPS attached silently — no spinner, no
  map, note persisted first, fix backfilled async. Reverse geocoding **never
  at capture** (it's a network call; offline-first is sacred) — lazy at
  display, coordinates are the data, the place name is sugar.
- One-shot fix done right: pre-warm `CLLocationManager` +
  `startUpdatingLocation` on sheet appear and cache the latest fix (rapid
  multi-capture shouldn't cold-spin GPS); **not** `requestLocation()` (~10s
  cold) and not `CLLocationUpdate.liveUpdates` (no accuracy control).
- Permission UX that never taxed capture: When-In-Use + precise, never Always;
  in-context priming sheet before the cold system prompt; first capture never
  interrupted; denied → timestamp-only with no per-capture nag.
  `NSLocationWhenInUseUsageDescription` is required or the app crashes;
  precise needs no separate entitlement.
- Don't persist a pending/denied location-state enum — "pending" is transient
  and a persisted flag goes stale; absent coordinates simply mean no location.
- **The hard platform gate (promote as fact):** a no-launch App Intent under
  When-In-Use **cannot get any GPS fix** while the app is backgrounded — a
  platform rule, not a tuning problem — and the intent's process may suspend
  before an async backfill lands. External no-launch captures are
  timestamp-only, permanently.

### Media / now-playing (→ #2 decides whether it's in scope at all)

The feasibility map is settled fact: Apple Music readable in-foreground
(MediaPlayer/MusicKit, behind a media-library permission) and — verified on
one device/OS — even from a no-launch intent, best-effort only; **Apple
Podcasts has no API at all** (share-a-URL is the only route);
`MPNowPlayingInfoCenter` is publish-only; MediaRemote is private, rejected.
Whether the restart wants media context at all is a fresh scope call; usage
evidence is silent (shipped too late).

---

## 6. Classification / tagging — re-open, with the history stated precisely (→ #3)

Source: `docs/adr/0007-note-types-context-bundles.md`, product-lead memory
`project_vnext-types-surfaces-context.md`, design-lead memory
`types-and-context.md`.

Get the lineage right, because it's easy to invert: **the spike never had
tags, and never deferred classification to triage.** Its shipped v1 banned
organizing outright ("no folders, tags, categories"). Its ratified successor
position (ADR 0007) allowed exactly two hardcoded *types* under the ruling
that **a type is a capture-context bundle plus an export frontmatter contract
— not an organizational taxonomy**: selection at the capture trigger only
(the surface *is* the selection; no picker in the flow), untyped as the
permanent default and fastest path, types never driving in-app organization,
emitted as a plain `type:` frontmatter key and **deliberately not Obsidian
`tags:`** — taxonomy is the vault's job. Type repair lived in triage, "where
Jackdaw does decisions."

Verdict: **re-open, all of it.** Jackdaw's tagging is an owner-ratified scope
*expansion* the spike explicitly refused, so 0007 is not a design to copy in
either direction. What it contributes to #3 is evidence:

- **The capture-speed argument is the durable part.** Every mechanism 0007
  chose — selection at the trigger, untyped-as-default, context as affinity
  never requirement (capture never blocks, absence repaired later, quietly) —
  exists to keep the fast path fast. #3's tagging design will be judged
  against the same constraint, and the design-lead owns making that trade
  explicit.
- **The `tags:` vs `type:` distinction was load-bearing**, not stylistic:
  emitting into Obsidian's live tag index makes the app a filer by proxy.
  If the restart emits real `tags:`, it does so knowingly — that's part of
  the ratified expansion's cost, not a detail.
- **Two triage dependencies need new answers:** repair-later has no "later"
  without triage, and "types never drive in-app organization" was what kept
  labels from becoming browsing — a guardrail the funnel principle still
  demands in whatever form tags take.
- The persistence pattern if types/tags are stored — raw-string-backed field
  with a default (`typeRaw`), additive migration, unknown values degrade
  gracefully, behavior routed through one spec seam — promotes as technique
  (→ #15).

---

## 7. Navigation and triage machinery — drop, with named survivors

### Drop

Source: `docs/adr/0004-navigation-triage-root-capture-sheet.md`,
`docs/slices/slice-4-triage.md`, design-lead memory `nav-model.md`,
`snooze-model.md`, `docs/design/capture-and-triage-flows.md` §2–3.

Gone with the stage, wholesale: triage-as-root and the auto-presented capture
sheet over it (ADR 0004 — already half-reversed by the spike itself);
keep/snooze/discard and the swipe idiom; the entire snooze model
(`snoozedUntil`, session boundaries, anti-graveyard nudges); the
discard-undo banner; the note editor as edit-before-export; batch-export UX;
"return to inbox"; the `inbox/snoozed/kept` status axis. Also the two
capture-wave guardrails phrased against Triage views — restate, don't
inherit.

### Survivors embedded in the wreckage (→ #15, and #2 for the invariant)

- **The keyboard-vs-bottom-chrome trap**, discovered on hardware: iOS 26's
  floating Liquid Glass tab bar sits *behind* a raised keyboard —
  launch-to-keyboard over a tab bar left the only way out unreachable. The
  sheet fixed it by construction, and gave a deterministic `onDismiss` (the
  prune trigger `TabView.onDisappear` couldn't reliably provide). The rule:
  **never leave the only way out of a screen behind the keyboard**, and
  device-validate any keyboard/floating-chrome interaction.
- **The funnel invariant, restated without triage:** home is never a growing,
  browsable library; everything downstream of capture is status and counts,
  never re-readable content; no history/"recently exported" view, ever.
  With triage cut, the restart may need *no* content list at all — that's
  #2's navigation question, derived fresh from capture-first.
- **One primary affordance, no duplicate chrome; labels are unique per
  action** ("Capture" ≠ "New note"). Transient chrome stacks above persistent
  chrome.
- Six technical patterns from the triage slice, all scope-independent:
  raw-string-backed enums for `#Predicate` reliability; state vs reason as
  separate persisted fields; no `Calendar` inside `#Predicate` (compute dates
  at write time, filter in a pure injectable function); deferred-delete-in-
  memory beats a tombstone because a kill resolves in the note's favor; iOS
  has no system snackbar (any toast is a custom view: materials, safe areas,
  VoiceOver announcement); never `Date()` in a test assertion path.

---

## 8. External capture surfaces — re-open against the evidence (→ #2; platform facts → #15)

Source: ADRs 0005, 0008, 0009, design-lead memory `external-capture.md`,
tech-lead memory `capture-nav-and-external.md`.

The platform facts promote as facts: widgets and Control Center controls
cannot collect text (the system text prompt via `requestValueDialog` is a
Shortcuts/Siri affordance), so any surface architecture is forced into two
lanes — no-launch parameter surfaces (timestamp-only by the GPS gate) and
launcher surfaces that foreground the app and get full context free. One App
Intent powers every surface; extensions that never touch the store need no
App Group; `CaptureService` as a UI-free, intent-free, unit-testable core is
the right seam shape regardless of scope.

The *scope* re-opens, and the evidence cuts against ambition: the Action
button — the spike's best-case external surface — never became habit, while
Siri/Shortcuts and the plain app did the actual work. The restart should ship
in-app capture (+ the intent seam, which Siri gets nearly free) and let
demonstrated pull, not platform capability, justify each further surface.

---

## 9. Stack — promote one, re-open one, keep the facts (→ #5, #6, #7, #15)

- **Min iOS target 26 (→ #5): promote.** The reasoning is unchanged and
  triage-free: single user, owner's own phone, no install base; highest
  target = cleanest API surface, fewest availability forks for an owner
  auditing unfamiliar Swift; raising later is cheap, lowering is costly.
  SwiftData floors at 17 regardless.
- **SwiftData (→ #6): re-open, as CLAUDE.md already directs.** The spike's
  stated rationale was triage-inflected ("queried for the triage inbox,
  mutated as notes move through that machine"); without triage, notes are
  shorter-lived and the store's job shrinks. The spike's *facts* carry into
  the decision: SwiftData worked without incident; `@Model`/`@Query` mapped
  cleanly to the owner's web mental model; it's built on Core Data, so it's
  not a one-way door; and the capture model's autosave leans on the
  main-context autosave behavior.
- **MVVM ↔ SwiftData split (→ #15): promote.** "Views own reads, a thin
  view-model owns write commands" — `@Query` is a View-only wrapper and can't
  be hoisted into a VM without losing reactivity; the VM stays
  SwiftUI-decoupled with the `ModelContext` injected per call, testable
  against an in-memory container. Fighting this with strict all-data-in-VM
  MVVM fights the framework.
- **Project mechanics (→ #7): promote.** The Xcode project format
  (filesystem-synchronized groups, objectVersion 77) picks up new `.swift`
  files automatically — no `project.pbxproj` surgery when adding files
  outside Xcode. Schema evolution: add fields at the slice that uses them;
  additive optional-or-defaulted properties migrate lightweight and free;
  no `SchemaMigrationPlan` before there's real data.

---

## 10. CI / TestFlight — promote, handed to #9 explicitly

Source: `docs/adr/0006-xcode-cloud-ci-testflight.md`, `docs/ci/xcode-cloud-setup.md`,
tech-lead memory `xcode-cloud-ci.md`. Verdict recorded here *for #9* so it
isn't dropped by both issues.

- **The shape re-ratifies as-is**: two owner-configured workflows — `PR CI`
  (PR → `main`: build + unit tests only, ~10 min) and `TestFlight` (merge →
  `main`: archive + Internal Testing, ~15–20 min). Cloud-managed signing is
  the point: it removes provisioning from the recurring path. Internal
  TestFlight has no Beta App Review; quota is 25 compute-hours/month, no
  rollover, ~5–6 realistically used; UI tests never run in the cloud (compute
  hours are wall-clock). Sequencing insight: prove `PR CI` green before
  wiring `TestFlight`.
- **The caveat this repo already lost once, verbatim rule:** the docs-only
  skip (Files & Folders start condition excluding `docs/`, `.claude/`,
  `CLAUDE.md`) goes on **`TestFlight` only — never on `PR CI`**. `PR CI` is a
  required status check; a skip condition there leaves a docs-only PR with a
  required check that never reports, which blocks the merge.
- Gotchas that cost real time, all still live: **ITMS-90626** — App
  Intents-visible strings must not contain "apple" (the workflow runs green,
  the build silently never appears in TestFlight, the rejection arrives by
  email — check the delivery log before suspecting start conditions);
  first-Cloud-build number colliding with a manual upload (bump
  `MARKETING_VERSION`); Xcode Cloud sees only *shared* schemes, with the Test
  action scoped to the unit-test target so the cloud structurally can't run
  UI tests; `ci_post_clone.sh` stamps unique build numbers (already carried
  into this repo, inert).
- The spend guardrails (agent never triggers/reconfigures; triggers never
  match WIP branches; local simulator is the inner loop) are already standing
  policy in `docs/dev-workflow.md`.

---

## 11. Process, a11y, and identity — promote (→ #15)

- **"Don't handwave hardware."** The tab-bar trap was documented as an
  acceptable "wrinkle" and became a field defect. When a design puts
  keyboard, sheet, or floating chrome near persistent chrome, "does the way
  out stay reachable?" is a must-verify on device, not a footnote — and
  "matches App X" only counts if App X does that *exact* combination.
- **"`PR CI` green ≠ done."** Everything load-bearing about the vault path
  (picker, bookmark across cold relaunch, sync ingestion, re-grant) is only
  provable by an owner on-device checklist. Slice protocols should say so.
- **The a11y baseline** (scope-independent, per-screen): Dynamic Type via
  semantic styles only; every swipe action mirrored as VoiceOver custom
  actions + long-press menu; autosave silent to VoiceOver (announce once on
  "New note", never per keystroke); ≥44pt targets; WCAG AA contrast; state
  never by color alone; Reduce Motion → cross-fade; system colors/materials
  make Dark Mode and Increase Contrast free.
- **Native-feel risks for a web-shaped owner**: the boxed-textarea-plus-
  Submit capture screen is the highest-risk web reflex (native is full-bleed,
  keyboard-as-chrome); never rebuild the system document picker (it's also
  what mints the bookmark); no custom fonts/sizes/controls; no first-run
  permission or setup gates — everything lazy and in-context.
- **No speculative abstraction**: no plugin systems, no type-erased provider
  registries; abstract when the *third* concrete case arrives.
- **Naming mechanics**: App Store display name ("JackdawNotes" registered as
  a placeholder, changeable while unreleased) ≠ bundle ID
  (`com.jimcodes.Jackdaw`, fixed) ≠ internal codename. Renaming the store
  listing later touches no code, so the marketable-name decision stays
  unblocked and deferred.

---

## 12. Follow-up ledger

- **#2 (PRD):** usage evidence (§1) seeds success criteria; funnel invariant
  restated (§7); nav derived fresh; media-context and external-surface scope
  calls (§5, §8).
- **#3 (classification):** §6 — ADR 0007 as evidence; the `tags:` cost named.
- **#4 (export ADR):** §3 — mechanism + serializer promote; retention/
  surfacing re-opened under the simplicity rule; poison-note question posed.
- **#5 (min target):** §9 — re-ratify iOS 26.
- **#6 (persistence):** §9 — re-decide with the spike's facts as input.
- **#7 (Xcode project):** §9 project mechanics.
- **#9 (CI):** §10 — ADR 0006's verdict handed over, `PR CI` caveat included.
- **#12 (location):** §5 — mechanics ready; the attach-or-not decision open.
- **#15 (persona memory):** the promote-into-memory ledger from §§3–11.
