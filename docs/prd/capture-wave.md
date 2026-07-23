# Jackdaw v1.x "capture wave" — proposed scope & build order

> **Status: PROPOSED — awaiting owner ratification** (partially ratified: the
> §2 type set — hardcoded Place + Listening — was ratified by the owner
> 2026-07-23, with the direction to keep future extensibility options
> considered; see §2's "Extensibility path").
> Synthesized 2026-07-23 from three tripod position papers (full positions in
> `.claude/agent-memory/{product,design,tech}-lead/`). Where the personas
> disagree, the disagreement is preserved in §7 as an explicit owner decision
> point rather than papered over. On ratification: the §8 ADRs land as their own
> PRs first, GitHub issue #21 gets updated, and per-slice issues are filed.

**The wave, in one sentence:** improve what a capture *knows* (note types +
richer ambient context: current song/podcast, location) and where a capture can
*start* (external surfaces: Action button, Shortcuts, widget, Control Center),
while keeping capture-in-seconds sacred and the funnel principle intact.

Owner's framing (verbatim, 2026-07-23):

> - Adding types of notes to identify different contexts – eg "i visited this
>   restaurant" or "this is an interesting thought about a podcast I'm
>   listening to". Continued focus should be on quick capture.
> - Additional capture surfaces (issue #21 covered this as a 1.x fast follow) –
>   eg widget, shortcut, control center. This should be able to trigger
>   different types of notes.
> - More note context – eg current song playing, current podcast and location.
>   Required context can be tied to note types.

---

## 1. The governing ruling (all three personas aligned — ratify this first)

**A note type is a capture-context bundle plus an export frontmatter contract.
It is not an organizational taxonomy.** "I visited this restaurant" doesn't
mean *file under Restaurants*; it means *the context that matters here is
where I am — grab it so I don't have to type it*. Downstream, `type:` becomes
a frontmatter field so the **vault** — where taxonomy legitimately lives — can
route and query. Jackdaw delivers a richer, pre-labeled payload and forgets it.
Under this ruling (and only under it) types survive the v1 bans on organizing
and on filing decisions at capture time.

**The five guardrails (these are the actual decision):**

1. **Type selection happens at the trigger, never inside the flow.** The typed
   surface *is* the selection — a "Place" widget button, a "Listening"
   shortcut. Choosing the trigger and choosing the type are one gesture. No
   mandatory type picker anywhere in capture.
2. **Untyped is the permanent default and must remain the fastest path.** A
   fleeting thought never waits on a classification. Untyped is not "missing a
   type" — it *is* the plain fleeting note, the most common capture.
3. **Types never drive in-app organization.** No filtering, grouping, sorting,
   or counting Triage by type; no per-type inboxes. Triage stays one
   drain-to-empty list. A type renders as a passive, editable chip — nothing
   more.
4. **Taxonomy is the vault's job.** Emit `type: place` as a plain frontmatter
   field — deliberately *not* Obsidian `tags:` (that would be Jackdaw doing
   vault taxonomy). Vault-side templates transform it as the owner pleases.
5. **Type is editable/clearable at triage** like every other piece of context.
   Triage is the app's decision surface; "what kind of note was that" is a
   triage-shaped decision.

If a future proposal breaks guardrail 1 or 3, it's filing, and it's out.

## 2. Scope

### Types: two hardcoded types plus untyped. No type management UI. *(RATIFIED by owner 2026-07-23, with the extensibility direction below.)*

- **`Place`** — context affinity: precise location + place name (the
  "visited this restaurant" case, generalized).
- **`Listening`** — context affinity: current media item, song *or* podcast
  (the "thought about a podcast" case, generalized).
- Generic names on purpose: "Restaurant" invites "Bar/Café/Shop" siblings and
  a taxonomy to curate. Place/Listening cover both stated situations with no
  room to proliferate.
- **Types are code** — a `String`-backed enum (the proven `statusRaw`
  pattern), not user data. A type is a context bundle + frontmatter contract;
  that's an enum case with a code descriptor (`wantsLocation` /
  `wantsNowPlaying`), not a DB row. The sole user is a developer; a third
  type, if daily use demands one, is a small PR. Design caps the UI at ~6
  types if the list ever grows.
- **Context affinities, never requirements** (design-lead's reframe of the
  owner's "required context", recommended unanimously): capture never blocks
  on missing context, triage rows never warn, absence surfaces only in the
  editor as a quiet repair affordance ("No location captured — Use current
  location"). A restaurant note without a fix is not worthless — the text
  carries the restaurant. Missing context = omitted frontmatter keys, never
  empty values.

### Extensibility path (owner directive 2026-07-23: considered now, built later)

Hardcoded types are the ratified scope for **this wave**; the owner wants the
road beyond kept deliberately open. The ladder, cheapest first — a future
release climbs one rung only when the previous rung demonstrably chafes:

1. **Types stay code; the enum grows.** A new type = one enum case + a
   descriptor + (optionally) a typed shortcut/widget button — a small PR. For
   a single user who owns the repo, this is a real extensibility mechanism,
   not a cop-out. Chafes when: the owner wants a new type *away from a dev
   machine*, or edits become frequent.
2. **Data-driven type definitions, no UI.** Types declared in a bundled or
   user-editable config (plist/JSON — conceivably even a file read from the
   vault, so the notes system defines its own intake). A type definition
   names: raw value, display name, SF Symbol, and which of the *existing*
   context affinities it wants (location / now-playing). No new context
   kinds — definitions can only recombine providers that exist in code.
   Chafes when: definitions want per-type behavior that isn't expressible as
   data.
3. **User-defined types in-app** (`@Model` entity + management UI). The full
   product feature — and a taxonomy-tending settings surface, which is why it
   sits last and needs its own funnel-principle argument when its day comes.

**Forward-compat commitments this wave makes now** (so rungs 2–3 stay
additive migrations, not rewrites — these go into ADR 1):

- `typeRaw` is a **plain stored `String`**, not constrained to the enum — an
  unknown raw value must degrade to untyped at display (the
  `NoteStatus`-style `?? .quick` fallback), never crash or block export. Rung
  2/3 values then persist with zero schema change.
- The **frontmatter `type:` key emits the raw string verbatim** — the vault
  contract is "a short stable string", not "one of these two words", so new
  types are automatically export-compatible.
- **All per-type behavior routes through the single `NoteTypeSpec`
  descriptor** — the one seam a data-driven registry (rung 2) would replace.
  No type-switching scattered in views or the serializer.
- **The known migration cost, named:** the intent's type parameter. A static
  `AppEnum` (this wave) is baked into Shortcuts at build time; dynamic types
  (rung 2+) require migrating that parameter to an `AppEntity` +
  `EntityQuery`. Contained to the intent layer, but it is the one place rung
  2 costs real work — recorded here so it's priced in, not rediscovered.

### Context providers: exactly two, no plugin system

- **Location** — exists (v1). Unchanged in-app; external story in §4.
- **Now-playing** — new: a second concrete `NowPlayingProviding` protocol
  mirroring `LocationProviding`'s shape (one-shot async snapshot, plain value
  type, MediaPlayer import only in the concrete impl). `CaptureService` grows
  a second optional provider and consults the note type's descriptor.
- **Explicitly not**: a type-erased `ContextProvider` registry. Two concrete
  optionals + a boolean spec is simpler and fully testable; abstract when a
  *third* context kind actually arrives (rule of three). Weather, calendar,
  motion stay out.

### Surfaces: see §4 for the model; the candidate set is Action button,
Shortcuts/Siri, Home-Screen widget (small + medium), Control Center control,
Lock Screen controls. The first-tranche cut line is owner decision point §7.2.

## 3. Feasibility verdicts (tech-lead, researched with citations — the wave's GPS-gate analog)

Full research + sources: tech-lead memory
(`.claude/agent-memory/tech-lead/now-playing-and-v1x-wave.md`); a formal
feasibility doc mirroring `docs/feasibility/external-capture-precise-gps.md`
accompanies the media-context ADR.

| Source | In-app (foreground) | No-launch intent (background) | Via Shortcuts parameters |
|---|---|---|---|
| **Apple Music** | **YES** (`MPMusicPlayerController.systemMusicPlayer` / MusicKit; costs an `NSAppleMusicUsageDescription` permission prompt) | **Unverified — assume NO until spiked** (S1) | **YES** ("Get Current Song") |
| **Apple Podcasts** | **NO** — no API at all | NO | **NO** — no current-episode action |
| **Overcast / 3rd-party podcast apps** | NO | NO | **YES for Overcast** ("Get Current Episode Info", incl. timestamped URL) |
| **System-wide (Spotify et al.)** | **NO** public API (`MPNowPlayingInfoCenter` is publish-only; MediaRemote is private — rejected) | NO | NO (Spotify Web API is a network-side escape hatch — see §7.5) |

**Honest product implications:**

- **"Current song"** — feasible: automatic in-app (Apple Music, foreground) and
  externally by piping Shortcuts' *Get Current Song* into the capture intent.
- **"Current podcast"** — degraded: feasible *only* as piped Shortcuts context
  from an app that exposes it (Overcast confirmed; Apple Podcasts dead). If
  the owner uses Apple Podcasts, the podcast wish is auto-context-dead — the
  Listening *type* still works, but the episode gets dictated by hand.
- **Location** — unchanged from v1: full precision in-app/foreground; a
  no-launch intent still gets none (ADR 0005 stands).

**The load-bearing architectural consequence (unanimous):** the reliable route
to external context is **context supplied by the caller as intent
parameters**, not read by us in the background. This shapes all of §4.

## 4. The surface model — two classes (platform-forced, and it reads clean)

Widgets and Control Center controls **cannot collect text** (platform rule —
no dialog UI from a widget button; `requestValueDialog` is a Shortcuts/Siri
affordance). That forces — happily — a clean two-lane architecture:

1. **Parameter surfaces — Action button, Shortcuts, Siri.** No-launch
   (`openAppWhenRun = false`): system text prompt / dictation, one-shot
   `CaptureService.commit`, type as an intent `@Parameter`, context piped in
   as optional parameters by the invoking shortcut (Get Current Song /
   Overcast episode). **The speed lane.** Location: none or cached (§7.4).
   The Action button runs a Shortcut, so it inherits all of this; it stays
   bound to the *untyped* capture — the fastest path stays zero-decision.
2. **Launcher surfaces — widgets, Control Center, Lock Screen controls.**
   Deep-link into the app's **Capture sheet with the type preapplied**
   (keyboard up). Launching foregrounds the app, so **precise GPS and the
   Apple Music read come back for free** — launcher surfaces get *full*
   ambient context, better than any background cleverness. The medium widget
   (2–4 type buttons) is the flagship typed-capture surface.

Per-surface verdicts (design-lead, HIG-checked): **build** Action button,
Shortcuts/Siri, small widget (untyped launcher), medium widget (type buttons),
Control Center "New note" control (+ same control in Lock Screen slots);
**skip** systemLarge widget (only inbox content could fill it — forbidden by
the funnel principle: no note previews ambient on the Home Screen), accessory
Lock-Screen widget families, StandBy/Watch/Back-Tap-specific work.

**Process-model notes (tech-lead):** widget/control extensions are separate
processes, but under the launcher architecture **no extension ever touches
the SwiftData store** — so **no App Group and no store migration this wave**.
The deferral (and its future one-time cost, if a widget ever *displays* store
data) is recorded in the surfaces ADR. `CaptureNoteIntent` lives in the app
target; the intent's `NoteTypeAppEnum` mirrors the persistence enum so
`NoteType` stays free of AppIntents imports.

**Capture-sheet & context display (design-lead):** a thin non-interactive
context strip in the sheet header (type chip + place/media chips appearing as
context resolves — reserved height, no cursor displacement, no announcements,
cross-fade gated on Reduce Motion, folding into #19's scope). Triage rows keep
the single secondary context line with strict truncation priority (time →
place → media; time never drops). Editor Context section gains: type menu
row, "Use current location" backfill, media row (view + Clear only — **no
media picker, ever**). Chips are symbol + label, never color alone; symbols
shape-distinct per type (widgets/controls render monochrome in vibrant modes);
44pt targets; VoiceOver labels per chip.

## 5. Proposed slice order

Walking-skeleton discipline: riskiest platform unknown first, every slice
lands on-device via the existing PR → TestFlight pipeline.

| # | Slice | Proves / retires |
|---|-------|------------------|
| **S1** | **Spike (timeboxed, owner on device): now-playing read.** Media-library permission + foreground `nowPlayingItem` read; then the same read inside a no-launch intent. | The wave's feasibility gate: is Apple Music context foreground-only or also background? Output feeds the media-context ADR. Pure risk retirement. |
| **A** | **External skeleton: text-only `CaptureNoteIntent`** + `AppModelContainer.shared`, invoked from Shortcuts + **Action button**. Untyped, timestamp-only note lands in Triage. | The no-launch capture → SwiftData round-trip and the system-prompt UX — the validation ADR 0005 explicitly deferred. The wave's walking skeleton. |
| **B** | **NoteType end-to-end:** enum + `typeRaw` (additive migration) + editor type row + capture-sheet type chip + `type:` frontmatter (golden tests) + `NoteTypeAppEnum` on the intent + two typed shortcuts. | The whole type thesis (guardrails 1–5) with zero new context tech; frontmatter contract v2 proven against the real vault. |
| **C** | **In-app now-playing:** `NowPlayingProviding` + media fields on `Note` + per-type descriptor wiring + media frontmatter + capture-strip/editor display. (Shape depends on S1.) | The second context provider without a plugin system; the media permission UX. |
| **D** | **Piped context via Shortcuts:** optional media `@Parameter`s + owner-authored shortcuts (Get Current Song → intent; Overcast episode → intent). | Context-via-parameters composes in practice; the podcast wish in its only feasible form. |
| **E** | **Launcher surfaces:** small + medium widget (type buttons, deep link) and Control Center control (`OpenIntent`, dual-target membership) + Lock Screen slots. First extension targets in the project — expect signing/provisioning friction; that's why it's its own slice. | Extension processes, deep-link routing into the sheet, the no-App-Group claim. |
| **F** | **Last-known-location cache** for external captures, with `fixedAt` provenance + `location_source: cached` frontmatter + visible "approximate" marking in the editor. Floats independently; ships only per §7.4. | The degraded-location story; tunable staleness policy. |

A before B (the intent skeleton is the bigger unknown; types are additive on
top). B before C/D (types gate per-type context). E late (UX breadth, not
risk — but see §7.2). The **ADR 0004 auto-present flip** attaches to A or to
observed behavior per §7.1.

## 6. Success criteria (owner-behavior style, per PRD §6)

1. **Capture moves outside the app** — over a real usage window, external
   surfaces become the majority origin of captures.
2. **Typed capture costs zero extra gestures** — choosing a typed trigger is
   no slower than the plain one; no capture is abandoned over a type decision.
3. **The promised context actually arrives** — observable as the owner
   *stopping* typing "at Luigi's" / "re: episode X" into note bodies.
4. **The vault consumes the fields** — `type:` and media/location frontmatter
   are actually used by vault templates/queries. A field nobody reads gets
   cut; frontmatter is a contract, not a dumping ground.
5. **Triage stays one list and still drains** — no type-based deferral piles;
   no inbox growth from easier capture outpacing triage.
6. **Carryover bars hold** — weekly use continues; keepers land clean; the
   funnel stays empty.

## 7. Owner decision points (the tripod's real disagreements, teed up)

1. **When does the Capture sheet stop auto-presenting (ADR 0004 endgame)?**
   *Design-lead:* flip in slice A — once one external surface exists, opening
   the app means "process", not "type"; one boolean, trivially revertible;
   requires the Triage root's compose affordance to become primary chrome.
   *Product-lead:* behavior-gate it — flip only when external capture is
   demonstrably the majority path (criterion 6.1); flipping early demotes
   capture behind the pile. **Synthesis recommendation:** flip in slice A
   (cheap, revertible, owner validates on-device) but *revert without debate*
   if a week of real use shows in-app capture still dominant.
2. **First-tranche surface breadth.** *Product-lead:* Action button +
   Shortcuts first; every further surface added one at a time as the owner's
   hand actually reaches for it. *Design-lead:* the medium widget is the one
   surface that makes types real — without it, surface-implies-type collapses
   and types exist only as a triage picker; wants A + B + medium widget as the
   coherent minimum, happily trading away per-type controls and accessory
   widgets. **Synthesis recommendation:** commit A–B now, decide E's timing
   when B lands — by then the owner knows whether typed capture pulls.
3. **`type:` frontmatter for untyped notes — emit or omit?** Tech-lead leans
   emit-always (`type: quick`; a stable discriminator beats an implicit
   default for vault automation); omit-when-absent is the house discipline
   everywhere else. Pick once; renames later are breaking changes to vault
   queries.
4. **External location: cache vs. foreground-flash vs. nothing.** Tech-lead:
   build the cache (cheap, provenance-stamped, tunable staleness); recommends
   *against* a dedicated `openAppWhenRun = true` foregrounding intent (the
   launcher surfaces already cover foreground-with-full-context, with better
   UX). Design-lead hard line: **a stale cached location must never silently
   stamp a Place-typed note** — confidently-wrong poisons the export;
   place-typed capture should route through launcher surfaces where the real
   fix exists. Product-lead: the foreground flash spends the very no-launch
   value external capture exists for. **Synthesis recommendation:** slice F
   ships cache for *untyped* external captures only, visibly marked
   approximate; Place-typed capture is a launcher-surface (foreground) story.
5. **Two owner inputs that gate scope:** *Which podcast app do you actually
   use?* (Overcast → slice D delivers the podcast wish; Apple Podcasts → the
   auto-context half is dead and we say so in the ADR.) *Are you a Spotify
   user?* (If yes, the Spotify Web API route — OAuth + first network
   dependency in a fully-local app — becomes a real but expensive option;
   recommendation is to reject it unless the answer is an emphatic yes.
   MediaRemote private API is rejected outright regardless.)

## 8. ADRs to write before building (each its own PR, ratify-then-build)

1. **NoteType model** — types-as-context-bundles ruling + guardrails; fixed
   code-defined raw-string enum (ratified 2026-07-23); per-type context
   descriptors in code; frontmatter contract v2 (`type:` policy per §7.3,
   media keys, omit-when-absent, golden tests); **the §2 extensibility
   ladder and its four forward-compat commitments** (string-tolerant
   `typeRaw`, verbatim `type:` emit, single-descriptor seam, the
   AppEnum→AppEntity migration cost).
2. **Media / now-playing context** — the §3 verdict matrix (written after S1
   answers the background question), chosen sources, Apple Podcasts and
   system-wide declared dead, MediaRemote rejected, Spotify per §7.5;
   companion feasibility doc carries the research.
3. **External-surface architecture** — parameter-vs-launcher taxonomy,
   context-via-parameters principle, intent-in-app-target, the **App Group
   deferral** (+ its future migration cost), the location-cache policy (§7.4),
   and the ADR 0004 flip decision (§7.1).

## 9. Wave non-goals (naming the pressure now, refusing it now)

- **No type-based Triage views** — no filter, sort, group, count, per-type inbox.
- **No type management UI** — types are code; no create/rename/edit screens.
- **No per-type structured fields, forms, or templates** — text + auto-context
  only ("Place notes should have a rating field" is a form builder; the vault
  applies structure after export).
- **No mandatory type** — untyped stays the default and fastest path.
- **No Jackdaw-side vault routing** beyond the frontmatter field.
- **No context history or streams** — no location log, no listening history;
  context attaches to a note and leaves with it.
- **No always-on background context collection** — anything cached exists
  solely to stamp the next capture, marked approximate.
- **No media picker** — media context is view + clear, never browse/choose.
- **No private APIs** (MediaRemote) — even under TestFlight-internal review
  tolerance.
- **No note-content widgets** — nothing from the inbox renders on the Home
  Screen or Lock Screen. Launchers only.
- **Still text-only; no AI enrichment; no automated triage; no new export
  destinations; no sync/account.** Unchanged from v1.

## 10. Process from here

1. Owner ratifies/amends: the §1 ruling + guardrails, the §2 scope, the §5
   order, and rules on the §7 decision points (§7.5's two inputs gate the
   media ADR).
2. The three §8 ADRs land as their own PRs (S1 spike feeds ADR 2).
3. Issue #21 is updated to point at this plan; per-slice issues (S1, A–F) are
   filed with the existing labels; this doc stays the durable "why".
