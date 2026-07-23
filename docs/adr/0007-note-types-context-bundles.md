# ADR 0007 — Note types as capture-context bundles (`NoteType` model + frontmatter contract v2)

> **Status:** Accepted — ratified via the capture-wave plan
> (`docs/prd/capture-wave.md`, PR #28, merged 2026-07-23; §1–§2, §7.2–§7.3, §8.1)
> and its checkpoint review. This ADR records the decision; the plan carries the
> full tripod positions and owner rulings.
> **Date:** 2026-07-23
> **Owner of decision:** product-lead (the ruling + guardrails) and tech-lead
> (the model + contract), arbitrated by owner.

## Context

The v1.x capture wave adds **note types** ("I visited this restaurant", "a
thought about this podcast") to improve what a capture knows. But v1
deliberately banned organizing — "no folders, tags, categories" and **"no
filing decision at capture time"** (JTBD 1, `docs/prd/mvp-scope.md`) — and
types sit one step from "categories". The wave needed a definition of *type*
that is compatible with the funnel principle, plus a concrete model that
survives SwiftData migration and the Obsidian frontmatter contract.

A second pressure: the owner ratified **hardcoded types for this wave** but
directed that **future extensibility options be considered now**, so later
releases don't discover one-way doors.

## Decision

### The ruling

**A note type is a capture-context bundle plus an export frontmatter contract.
It is not an organizational taxonomy.** The type selects *what ambient context
to auto-attach* (a Place note wants location; a Listening note wants the
current media item) and how the note is labeled for the vault — where taxonomy
legitimately lives. Five guardrails enforce it:

1. **Type selection happens at the trigger, never inside the flow** — the
   typed surface *is* the selection; no mandatory type picker anywhere.
2. **Untyped is the permanent default and the fastest path** — untyped *is*
   the plain fleeting note, not a note "missing" a type.
3. **Types never drive in-app organization** — no filtering, grouping,
   sorting, or counting Triage by type; a type renders as a passive, editable
   chip only.
4. **Taxonomy is the vault's job** — emit `type:` as a plain frontmatter
   field, deliberately *not* Obsidian `tags:`.
5. **Type is editable/clearable at triage** like every other piece of context.

If a proposal breaks a guardrail, it's filing, and it's out.

### The type set (this wave)

Exactly two hardcoded types plus untyped: **`place`** (affinity: precise
location + place name) and **`listening`** (affinity: current media item, song
or podcast). Generic names on purpose — "Restaurant" invites siblings and a
taxonomy to curate. **No type management UI.**

### The model

- `NoteType: String, Codable, CaseIterable` — cases `quick` (untyped
  default), `place`, `listening`. **Types are code, not user data.**
- `Note.typeRaw: String = NoteType.quick.rawValue` — a defaulted stored
  primitive, the proven `statusRaw` pattern: additive lightweight migration
  (ADR 0003), `#Predicate`-reliable, and adding a *case* later is not a
  schema change.
- **Unknown raw values degrade to untyped** at display (`?? .quick`), never
  crash or block export — `typeRaw` is deliberately *not* constrained to the
  enum (forward-compat commitment, below).
- Per-type behavior lives in a single code descriptor:

  ```swift
  struct NoteTypeSpec {
      let wantsLocation: Bool
      let wantsNowPlaying: Bool
  }
  ```

  **All** per-type behavior routes through this one seam — no type-switching
  scattered in views or the serializer.
- **Context affinities, never requirements:** capture never blocks on missing
  context, triage rows never warn, absence surfaces only in the editor as a
  quiet repair affordance. A restaurant note without a fix still carries the
  restaurant in its text.
- The App Intents layer mirrors the enum as a separate `NoteTypeAppEnum`
  (one-line mapping) so `NoteType` stays free of AppIntents imports — the
  same layering discipline as `LocationFix` vs CoreLocation.

### Frontmatter contract v2

Additive-only over the frozen v1 keys (`created`, `latitude`, `longitude`,
`accuracy_m`, `place`); omit-when-absent; snake_case; `yamlQuoted` escaping:

- **`type:`** — emitted **verbatim when present**; **omitted entirely for
  untyped notes** (owner ruling, plan §7.3, over the tech-lead's emit-always
  lean — recorded here so it isn't relitigated). An absent key *is* the
  plain-note default.
  - **Caveat, priced in now:** adding `type: quick` later would be
    **serializer-additive only** — vault queries identifying untyped notes by
    key-absence (`WHERE !type`) would break. Renaming any emitted value is
    breaking outright.
- **Media keys** (land with the media-context work, ADR 0002-successor for
  media): `media_title`, `media_artist`, `media_source`, `media_url` — flat
  optional primitives on `Note`, no sub-model.
- **`location_source: cached`** accompanies cache-stamped coordinates
  (ADR 0008).
- **Golden tests** per type in the `ExportTests` style, asserting key
  *absence* for untyped notes, not just presence for typed ones.

### Extensibility path (considered now, built later)

A future release climbs one rung only when the previous rung demonstrably
chafes **and** the climb has a named user-value case — developer convenience
alone doesn't justify a rung:

1. **Enum grows in code** (a new type = one case + descriptor — a small PR).
2. **Data-driven type definitions, no UI** (plist/JSON, conceivably read from
   the vault). Definitions can only recombine context providers that exist in
   code. Needs its own funnel-principle argument — cheap type creation is how
   two generic types become nine specific ones.
3. **User-defined types in-app** (`@Model` + management UI). Last on purpose;
   a taxonomy-tending settings surface needing its own funnel argument.

**Forward-compat commitments this wave makes** so rungs 2–3 stay additive:
string-tolerant `typeRaw` (above); `type:` emitted verbatim when present; the
single `NoteTypeSpec` seam (the one thing a rung-2 registry replaces); and the
named migration cost — the intent's static `AppEnum` must become an
`AppEntity` + `EntityQuery` for dynamic types (contained to the intent layer).

## Consequences

**Positive**
- Types accelerate capture (auto-context instead of typed context) and improve
  the handoff (pre-labeled payload) without becoming filing — the funnel
  principle survives by construction, not by vigilance alone.
- Additive migration end to end: existing rows read the `quick` default;
  the vault contract only gains keys.
- The extensibility ladder is priced: no rung requires a rewrite, and the one
  real cost (AppEnum → AppEntity) is named and contained.

**Negative / accepted**
- Untyped captures from the fastest paths need typing at triage *if the user
  cares* — work moves downstream, deliberately, to where Jackdaw does
  decisions.
- Two types may prove too few (or wrongly named); adding/renaming a case is a
  small PR, but renaming an *emitted* value breaks vault queries — names were
  chosen generic to reduce that risk.
- A type-shaped feature invites scope pressure (per-type fields, type
  management, type-filtered views). The wave non-goals
  (`docs/prd/capture-wave.md` §9) refuse each by name.

## Related

- `docs/prd/capture-wave.md` — the ratified plan (rulings, guardrails,
  slices); this ADR records its §8.1.
- ADR 0003 — SwiftData persistence (the additive-migration ground this
  relies on).
- ADR 0008 — external-surface architecture (where typed *triggers* live; the
  `NoteTypeAppEnum` parameter).
- `docs/prd/mvp-scope.md` §5 — the v1 non-goals this decision deliberately
  reopens under guardrails.
