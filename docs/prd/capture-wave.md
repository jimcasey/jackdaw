# Jackdaw v1.x "capture wave" — proposed scope & build order

> **Status: PROPOSED — decision points all RULED (2026-07-23); merge of this
> PR ratifies the remainder** (the §1 ruling + guardrails and the §5 order).
> Already ratified by the owner: the §2 type set — hardcoded Place +
> Listening, with the extensibility direction in §2's "Extensibility path" —
> and all five §7 decision points, including the media-source inputs (Apple
> Podcasts user, not a Spotify user → Apple Music is the only live media
> auto-context source; podcast metadata arrives via the share route).
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
- **"Current podcast"** — **auto-context-dead for this owner (ruled
  2026-07-23).** Piped Shortcuts context requires an app that exposes it
  (Overcast confirmed); **the owner uses Apple Podcasts**, which exposes
  nothing. The Listening *type* still covers podcast thoughts — labeled
  frontmatter, episode dictated/typed by hand — but we do not market it to
  ourselves as auto-context. Revisit only if the owner switches podcast apps;
  the intent's media parameters (§5 D) are app-agnostic, so a switch would
  need no code.
  **Amendment (owner-directed 2026-07-23): dead for *pull*, alive for
  *push*.** Apple Podcasts *can share* an episode — including timestamped
  links from the Now Playing screen or a transcript selection — and a
  Shortcut can be a share-sheet target. Shared-episode capture rides the
  parameter lane (§4) and slice D. This is the only route by which real
  Apple Podcasts metadata (canonical episode URL, optionally timestamped)
  reaches a note.
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

**Share-sheet route (parameter-lane variant, owner-directed 2026-07-23):** a
Shortcut configured as a **share-sheet target** receives a shared URL/text
(e.g. an Apple Podcasts episode link), prompts for the thought (Ask for
Input), and invokes `CaptureNoteIntent` with the episode piped into the same
optional media parameters — no new extension target, no App Group, no new
capture code. The gesture inverts capture (it starts in the source app,
~4 taps before typing) but matches the situation: a podcast thought usually
strikes while looking at the player. A **native Share Extension** (compose
field inside the share card) is explicitly **deferred**: it's a separate
process that reopens the App Group / store-sharing question deferred below,
for UX polish the Shortcut route already covers. Recorded in ADR 3 alongside
the App Group deferral.

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
| **A** | **External skeleton: text-only `CaptureNoteIntent`** + `AppModelContainer.shared`, invoked from Shortcuts + **Action button**. Untyped, timestamp-only note lands in Triage. **Includes the ADR 0004 flip (§7.1):** auto-present off, bare Triage root, compose button as primary chrome. | The no-launch capture → SwiftData round-trip and the system-prompt UX — the validation ADR 0005 explicitly deferred. The wave's walking skeleton, and the nav endgame validated on-device. |
| **B** | **NoteType end-to-end:** enum + `typeRaw` (additive migration) + editor type row + capture-sheet type chip + `type:` frontmatter (golden tests) + `NoteTypeAppEnum` on the intent + two typed shortcuts. | The whole type thesis (guardrails 1–5) with zero new context tech; frontmatter contract v2 proven against the real vault. |
| **C** | **In-app now-playing:** `NowPlayingProviding` + media fields on `Note` + per-type descriptor wiring + media frontmatter + capture-strip/editor display. (Shape depends on S1.) | The second context provider without a plugin system; the media permission UX. |
| **D** | **Piped context via Shortcuts:** optional media `@Parameter`s + two owner-authored shortcuts — **Get Current Song → intent** and a **share-sheet target shortcut** (shared Apple Podcasts episode URL + Ask-for-Input thought → intent). Parameters stay app-agnostic. | Context-via-parameters composes in practice — the song case (live read) and the podcast case (share push), covering both halves of the Listening type. |
| **E** | **Launcher surfaces:** small + medium widget (type buttons, deep link) and Control Center control (`OpenIntent`, dual-target membership) + Lock Screen slots. First extension targets in the project — expect signing/provisioning friction; that's why it's its own slice. | Extension processes, deep-link routing into the sheet, the no-App-Group claim. |
| **F** | **Last-known-location cache** for external captures, with `fixedAt` provenance + `location_source: cached` frontmatter + visible "approximate" marking in the editor. Floats independently; ships only per §7.4. | The degraded-location story; tunable staleness policy. |

A before B (the intent skeleton is the bigger unknown; types are additive on
top). B before C/D (types gate per-type context). E's timing is decided when
B lands (§7.2 ruling); F ships untyped-only per §7.4. Committed first
tranche: **S1 + A + B.**

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

## 7. Owner decision points — ALL RULED (2026-07-23)

1. **When does the Capture sheet stop auto-presenting (ADR 0004 endgame)?**
   **RULED: flip in slice A.** (Design-lead's position; product-lead had
   argued for behavior-gating on criterion 6.1.) The bare Triage root ships
   with the Action button; the root's compose affordance becomes primary
   chrome (bottom-docked, 44pt+, labeled); deep-linked captures present the
   sheet regardless of the flag. Escape hatch stands: *revert without
   debate* if a week of real use shows in-app capture still dominant.
2. **First-tranche surface breadth.** **RULED: commit A–B now; decide the
   medium widget's timing (slice E) when B lands** — by then the owner knows
   whether typed capture pulls. (Product-lead's one-at-a-time discipline,
   with design-lead's widget case explicitly queued as the first candidate,
   not dropped.)
3. **`type:` frontmatter for untyped notes.** **RULED: omit.** Only typed
   notes emit `type:` (`place` / `listening`); an absent key *is* the
   plain-note default, consistent with the house omit-when-absent discipline.
   (Overrides tech-lead's emit-always lean — noted so it isn't relitigated.
   The internal enum still carries an untyped case; omission is serializer
   policy, not a model change.) This is now frozen contract: adding
   `type: quick` later would be an additive change; *renaming* any emitted
   value would be breaking.
4. **External location for no-launch captures.** **RULED: cache for untyped
   external captures only, visibly marked approximate** (editor marking +
   `location_source: cached` frontmatter + `fixedAt` provenance). Place-typed
   capture routes through launcher surfaces where a real foreground fix
   exists — a stale cache never silently stamps a Place note (design-lead's
   hard line, honored). No `openAppWhenRun = true` foregrounding intent.
5. **Two owner inputs that gated scope — ANSWERED (2026-07-23):** the owner
   uses **Apple Podcasts** (→ podcast auto-context is dead; see §3's ruling —
   Listening remains a manual-context type for podcasts) and is **not a
   Spotify user** (→ the Spotify Web API route is rejected; the app stays
   fully local with no network dependency. MediaRemote private API was
   already rejected regardless). Net: the only *live* media auto-context
   source is **Apple Music** — in-app foreground reads (slice C) and
   Get Current Song piping (slice D).

## 8. ADRs to write before building (each its own PR, ratify-then-build)

1. **NoteType model** — types-as-context-bundles ruling + guardrails; fixed
   code-defined raw-string enum (ratified 2026-07-23); per-type context
   descriptors in code; frontmatter contract v2 (`type:` omitted for untyped
   per the §7.3 ruling, media keys, omit-when-absent, golden tests); **the §2
   extensibility
   ladder and its four forward-compat commitments** (string-tolerant
   `typeRaw`, verbatim `type:` emit, single-descriptor seam, the
   AppEnum→AppEntity migration cost).
2. **Media / now-playing context** — the §3 verdict matrix (written after S1
   answers the background question); Apple Music as the sole live
   auto-context source; Apple Podcasts and system-wide declared dead;
   MediaRemote and the Spotify Web API rejected (owner rulings, §7.5); the
   revisit trigger (owner switches podcast apps) recorded; companion
   feasibility doc carries the research.
3. **External-surface architecture** — parameter-vs-launcher taxonomy,
   context-via-parameters principle, intent-in-app-target, the **share-sheet
   route via Shortcuts** (amending v1's "no share-sheet ingest" non-goal —
   see §9) with the **native Share Extension deferred**, the **App Group
   deferral** (+ its future migration cost), the location-cache policy as
   ruled in §7.4 (untyped-only, marked approximate), and the ADR 0004 flip as
   ruled in §7.1 (flip in slice A, revert-without-debate escape hatch).

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
- **No native Share Extension** — v1's blanket "no share-sheet ingest"
  non-goal is **amended, not repealed**: share-sheet capture is in scope
  *only* as a Shortcut share-target feeding the intent's parameters (§4).
  A Share Extension target (and the App Group it drags in) stays out until
  the Shortcut route demonstrably chafes.
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
