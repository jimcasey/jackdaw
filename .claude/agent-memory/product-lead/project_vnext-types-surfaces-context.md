---
name: project_vnext-types-surfaces-context
description: v1.x/v2 wave position — note types, external surfaces, context providers; guardrails keeping types from becoming filing; PROPOSED, pending owner ratification
metadata:
  type: project
---

**Status: PROPOSED (2026-07-23), not yet owner-ratified.** My position paper for
the post-v1 wave (owner brief: note types, more capture surfaces, more context,
"continued focus on quick capture"). Consult before relitigating.

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
