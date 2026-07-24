---
name: project_vnext-types-surfaces-context
description: v1.x/v2 wave position — note types, external surfaces, context providers; guardrails keeping types from becoming filing; RULED 2026-07-23, see rulings section
metadata:
  type: project
---

**Status: RULED (2026-07-23).** Owner ruled on all decision points; synthesis +
rulings live in `docs/prd/capture-wave.md` (PR #28). My original position paper
below, then the rulings. Consult before relitigating.

## Owner rulings (2026-07-23) — settled, do not reopen

- **§7.1 ADR 0004 flip: I was OVERRULED.** Flip auto-present at slice A (design's
  ship-gate), not behavior-gated on criterion 1 as I argued. Escape hatch:
  revert without debate if a week of real use shows in-app capture still
  dominant. Accepted; my review flagged the one-week window as too
  hair-triggered (habit lag guarantees in-app dominance in week 1) — asked for
  a calibrated window, not a re-argument of the gate.
- **§7.2 tranche: my position won.** Commit S1+A+B only; medium widget (slice E)
  decided when B lands, design's widget case queued first, not dropped.
- **§7.3:** omit `type:` for untyped (overrode tech-lead's emit-always).
  Frozen contract: adding `type: quick` later = additive; renaming = breaking.
- **§7.4:** location cache for untyped external captures only, visibly marked
  approximate. Place-typed goes through launcher surfaces (real fix) only.
- **§7.5:** owner uses Apple Podcasts, not Spotify → podcast auto-context is
  **dead for pull, alive for push**: share-sheet Shortcut route (slice D) is
  the only path for real Apple Podcasts metadata. Apple Music = only live
  auto-context source.
- **§9 amendment:** v1's "no share-sheet ingest" non-goal amended (not
  repealed) — Shortcut-share-target-into-intent-parameters only; native Share
  Extension stays out until the Shortcut route chafes.

## Funnel fences I hold on the amendments (my review lines, PR #28)

- **Share route is justified by the Listening JTBD only** ("podcast thought
  strikes at the player"), not by generic share-ingest. Tripwire = any ask to
  add **non-media parameters** for shared content (generic `url:`/`source:`
  field, articles, photos, links-as-links). That's read-later/link-saving — a
  different product — and needs its own funnel argument, not a ride on this
  amendment. The shared URL is *context frontmatter on a text thought*; the
  thought (Ask for Input) stays the note.
- **Extensibility ladder rung 2** (data-driven type defs) must carry the same
  funnel-argument clause rung 3 has — a vault-readable type config is a
  taxonomy-tending surface in embryo. Chafe triggers are currently
  dev-convenience-worded; climbing also needs a user-value case.
- Success criterion 1 (external majority) survives the 7.1 overrule as the
  **revert/keep metric** for the flip, no longer its precondition.

## Slice A checkpoint review (PR #41, 2026-07-24) — my findings

- **Scope fidelity: clean.** Ships exactly the A row (untyped, timestamp-only
  intent; Shortcuts + Action button; the §7.1 flip). `JackdawShortcuts`
  (AppShortcutsProvider) ruled **plumbing, not creep**: S1 proved a bare
  intent is only an assemblable action; the provider is the minimal assembly
  making "invoked from Shortcuts + Action button" true, and Siri/Spotlight it
  lights up are inside the ratified §4 parameter lane. WATCH: the provider is
  where future typed shortcuts accrete — slice B's one Listening shortcut is
  ratified; anything beyond needs the plan.
- **Funnel line: no drift.** Bare Triage root, bottom-docked "New note",
  terse dialog copy ("Captured." confirms and closes — no view-note
  affordance). Good.
- **Finding I raised (fix-then-ship):** §7.1's ~2-week revert clock starts at
  Action-button *configuration*, but nothing designates where the config DATE
  gets recorded → asked for one line in spec validation step 2: record the
  date in STATUS/issue #30 when configuring. Without a date the recalibrated
  clock is unfalsifiable.
- **Criterion 6.1 measurability: deliberately NO origin field on Note.** For
  a single user, "is in-app capture still dominant" is answerable by the
  owner's own memory; a stored origin marker is analytics-shaped metadata
  that never exports. Incidental proxy: external notes are location-less —
  but slice F (cached location) erodes that proxy later; don't rely on it.
  Criterion 6.2 not evaluable until slice B (correct — nothing smuggled to
  serve it early).

## The core ruling I argued: types are context bundles, not filing

v1 banned "filing decision at capture time" (JTBD #1) and organizing (non-goal).
Types survive that ban **only** under these guardrails:

1. **A type is a capture-context bundle + an export frontmatter contract** —
   it selects which ambient context to auto-attach and what `type:` field the
   vault receives. It is NOT an in-app taxonomy.
2. **Type selection happens at the trigger, not in the flow.** A typed external
   surface (a "Place" shortcut, a "Listening" Action-button assignment) IS the
   selection — zero added gestures. No mandatory in-sheet picker, ever.
3. **Untyped stays the default and the fastest path.** Mandatory.
4. **Types never drive in-app organization**: no filtering/grouping/sorting/
   counting Triage by type, no per-type inboxes. One drain-to-empty list.
5. **Taxonomy lives in Obsidian.** Jackdaw emits `type: <x>` as a plain
   frontmatter field (deliberately NOT Obsidian `tags:` — vault templates can
   transform). Routing/organizing is the vault's job.
6. Type is editable/clearable at triage like other context (JTBD #3; also
   rescues timestamp-only external captures).

**JTBD for a type:** "capture a thought with the right context for its
situation without describing the situation" — the type substitutes automatic
context for manual typing (accelerant), plus "arrive in the vault pre-labeled
so vault-side automation can route it."

## Scope positions I took

- **Two hardcoded types + untyped: `Place` and `Listening`** (generic names, not
  restaurant/podcast, to prevent near-duplicate proliferation). Types are code.
  **No user-definable type editor / config UI** — same reasoning as the v1
  "clean seams, no plugin UI" ruling; owner is a dev, new types are code changes.
- **No per-type structured fields/templates** (rating for restaurants, quote
  field for podcasts) — that's a form builder; biggest creep vector this wave.
- **Sequencing: surfaces → type contract → context providers.**
  W0 walking skeleton = bare `CaptureNoteIntent` (no-launch, untyped,
  timestamp-only) + Action button + Shortcuts (issue #21 tranche 1) — de-risks
  the new platform ground while doing almost nothing.
  W1 = `type` field end-to-end (intent param → model → triage chip → frontmatter),
  zero new context tech.
  W2 = tech-lead feasibility spikes (parallel-able): now-playing API reality;
  external location routes (last-known cache vs openAppWhenRun=true flash vs
  **Shortcut-supplied parameters** — Shortcuts may fetch location/now-playing
  itself and pass them into the intent; potentially rescues both gaps).
  W3 = ship surviving providers wired to types.
  W4 = more surfaces (Control Center/widget/Lock Screen) as owner use demands,
  not as a suite.
- **ADR 0004 flip (stop auto-presenting Capture sheet) is behavior-gated**, not
  ship-gated: flip when external capture is the owner's actual majority capture
  path, not merely when it exists.

## Feasibility flags raised (tech-lead to verify)

- **Now-playing for third-party apps (podcasts, Spotify, Overcast) likely has NO
  public API** (MediaRemote is private; MPMusicPlayerController covers Apple
  Music only, needs media-library permission). This is a GPS-gate-class risk to
  the owner's headline "podcast thought" use case. Shortcut-supplied context is
  the candidate workaround. Do not commit "current podcast" scope until spiked.
- External GPS constraint from ADR 0005 still stands (timestamp-only no-launch).

## Wave non-goals I proposed (refuse now, by name)

No type-based Triage views; no type management UI; no per-type forms/fields;
no mandatory type; no Jackdaw-side vault routing beyond the frontmatter field;
no context history/streams (no location log, no listening history — context
attaches to a note and leaves with it); no always-on background context
collection; still text-only (no photo-of-the-dish creep); no AI enrichment;
no new export destinations; no notifications.

## Anticipated disagreements teed for owner

- design-lead: prominent in-sheet type picker (I say trigger-side only; quiet
  optional chip in editor at most); wanting the full surface suite at once.
- tech-lead: generalized ContextProvider registry (I concede a minimal protocol
  once the 2nd concrete provider exists; no registry/config); foregrounding
  variant for GPS (spike ok, cheaper routes first).
- owner gold-plating watch: per-type fields, type editor, weather/calendar/
  motion providers "while we're at it."

## Success criteria proposed (owner-behavior style)

1. Majority of captures originate outside the app (also the ADR 0004 flip gate).
2. Typed capture adds zero gestures vs untyped; no capture abandoned over a
   type decision.
3. The type's promised context lands attached+correct; owner stops typing
   "at Luigi's" / "re: podcast X" into bodies.
4. `type:` + context frontmatter actually consumed by the vault workflow —
   unused fields get cut.
5. Triage stays one list and still drains; no type-based deferral piles.
6. Carryover: still in weekly use; funnel stays empty.
