# Jackdaw — v1 MVP PRD

> **Status:** Draft for owner arbitration. Supersedes the scope portions of
> `concept-brief.md`. Owned by product-lead. Design flows (design-lead) and
> architecture/ADRs (tech-lead) hang off this doc; they do not redefine scope.
>
> **Governing principle (from CLAUDE.md):** Jackdaw is a *funnel, not an
> archive*. Notes flow **Capture → Triage → Export** and leave. If a feature
> helps fast capture or clean handoff, it's in. If it moves toward organizing,
> searching, or browsing past notes, it's out.

---

## 1. Problem

Fleeting thoughts arrive at bad moments — walking, mid-conversation, in a
queue — and the friction of opening a notes app, choosing where a thought
"goes," and typing it cleanly is high enough that the thought is lost. Existing
notes apps optimize for *retrieval and organization*, which makes them slow at
*capture* and turns every quick note into a filing decision. The result is
either lost thoughts or an ever-growing unsorted pile that never makes it into
the user's real notes system.

The user already has a permanent home for notes (Obsidian, backed by a GitHub
repo). What's missing is a **fast on-ramp** that gets a thought out of their
head in under a few seconds and reliably delivers the keepers into that home —
without becoming yet another place notes pile up.

## 2. Target user & context

The owner: a single user, a strong full-stack engineer, new to iOS. Already
runs a deliberate notes practice in Obsidian and refines notes with AI
*outside* this app. Technically fluent, opinionated about friction, and the
sole customer — so v1 optimizes for one real workflow, not a market.

Context of use: mostly one-handed, on a phone, in short bursts. Capture happens
anywhere (often distracted, sometimes offline). Triage happens later, in a
deliberate sit-down batch. Export feeds an existing, trusted vault the user
does not want polluted with junk.

## 3. Jobs to be done

1. **Capture a thought before I lose it** — get text out of my head with
   near-zero friction, ambient context attached automatically, no filing
   decision at capture time. The capture surface should be reachable fast,
   whether the thought strikes inside the app or from outside it (a system-level
   trigger).
2. **Come back later and clear the inbox** — review captured notes in a batch
   and make a fast keep-or-kill decision on each, without sorting into
   categories.
3. **Fix up a keeper before it leaves** — lightly edit a note's text (and the
   captured context) so what lands in my vault is clean.
4. **Get keepers into my real notes system** — export kept notes to Obsidian as
   markdown, with the captured context preserved, then have the app forget them.
5. **Trust that the funnel is empty and honest** — know that discarded notes are
   gone, kept notes made it out, and nothing is silently accumulating.

## 4. In scope for v1

**Launch & navigation model**
- The app **root is Triage** (the inbox). The **Capture sheet auto-presents on
  launch**, so the user lands ready to type; dismissing the sheet reveals Triage.
- Capture is a **presented modal sheet**, not a tab or mode.
- **Funnel invariant:** home is never a growing, browsable library. Triage is a
  *to-do list that drains to empty*, not an archive. Landing on Triage is
  landing on work-to-clear, not on a pile to browse.

**Capture**
- Primary in-app surface: the **text-note capture sheet** — typed with minimum
  taps, works while auto-presented on launch or invoked from within the app.
- Automatic context on capture: **timestamp** and **precise (GPS) location**.
- Capture works **offline**; notes queue locally.
- **One shared capture seam (`CaptureNoteIntent`)** underpins in-app and external
  capture. For v1 we **validate a single external surface — the Action button —**
  through this seam, plus the **precise-GPS-from-an-external-intent feasibility
  gate** (see below). Other external surfaces are v1.x (see non-goals).

**Triage**
- A **batch inbox** view of un-triaged notes (the app root).
- Per note, three actions: **Discard**, **Snooze** (defer to next session), and
  **Keep** (the keep-for-export action).
- Per note, **edit the note text** and **edit/correct the attached context**
  before keeping.

**Export**
- Export kept notes to **Obsidian** as markdown files, with captured context
  written as **YAML frontmatter**. Obsidian is the **only shipped v1
  destination**.
- **Retention: hold until sync confirmed.** A note stays local until the
  Obsidian write is *verified successful*, then it deletes. This depends on the
  chosen write mechanism being able to confirm success (see the write-mechanism
  ADR and its new confirmation requirement).

**Cross-cutting**
- Single user, single device. No account, no sync, no multi-device story.

> **Scope stance on "pluggable seams" (settled):** v1 ships **exactly one**
> capture source (text), **one** context set (time + location), and **one**
> shipped export destination (Obsidian). **Clean internal boundaries only** —
> no plugin system, no configuration UI, and no tests for hypothetical plugins.
> Keeping those seams from being hard-wired spaghetti is good code hygiene for
> tech-lead; *building, testing, or designing UI for extensibility is a
> non-goal.* See non-goals.

## 5. Explicit non-goals (v1 deliberately does NOT do)

- **No browsing, searching, or re-opening exported notes.** Once a note leaves,
  it's gone from Jackdaw. There is no history, archive, or "recently exported."
- **No organizing:** no folders, tags, categories, notebooks, or sorting during
  triage. Triage is keep/kill/snooze only.
- **No Apple Notes as a shipped destination.** The **only** shipped v1 export
  destination is Obsidian. Apple Notes is a **sanctioned intermediate build-order
  milestone** (owner arbitration) — a real de-risking deliverable used to prove
  the capture/triage loop *before* the Obsidian write path is solved — but it
  does not ship in v1 and is not a product feature. (Build-order device under
  the CLAUDE.md walking-skeleton rule, not v1 scope.)
- **No AI or automated triage.** Triage is fully manual in v1.
- **No pluggable-source or pluggable-destination product feature** (see scope
  stance above). No share-sheet ingest, quick actions, or implicit captures.
- **No external capture surfaces beyond the one validated (Action button).**
  Control Center control, Siri-as-primary, widget, Lock Screen, and home-screen
  quick actions are **v1.x fast-follow** — built on the same `CaptureNoteIntent`
  seam, not in v1. External capture does **not gate v1**.
- **No launch-to-empty-list / browsable-home model.** The root is Triage, but
  Triage is a drain-to-empty to-do surface; it must not become a browsable
  library (protected by the no-browsing/no-history non-goals above).
- **No rich media capture:** no photos, audio, voice-to-text, drawings, or web
  links as first-class types. Text only.
- **No context providers beyond time + location** (no now-playing, weather,
  calendar, motion, etc.).
- **No multi-device sync, backup, or cloud account.**
- **No note formatting/markdown editor.** Capture and triage are plain text;
  markdown structure is an export concern, not an editing feature.
- **No notifications / reminders / scheduled triage nudges.**

## 6. Success criteria

Because this is a single-user tool, success is measured by the owner's own
adopted behavior over a real usage period, not aggregate metrics:

1. **Capture is fast enough to be used in the wild.** From intent to captured
   text is a few seconds and a couple of taps — fast enough that the owner
   reaches for Jackdaw instead of losing the thought or using something else.
2. **The inbox actually gets cleared.** The owner runs triage sessions and
   drives the inbox toward empty, rather than letting it become the pile it was
   meant to prevent.
3. **Keepers reliably land in Obsidian**, correctly formatted with context
   frontmatter, with no data loss and no manual cleanup needed in the vault.
4. **The funnel stays empty.** Exported/discarded notes do not accumulate in the
   app; the owner trusts the app is not becoming an archive.
5. **The owner keeps using it** past the novelty window (e.g. still in weekly
   use after ~4 weeks). This is the real bar — a personal tool that gets
   abandoned failed regardless of feature completeness.

## 7. Settled decisions & remaining dependencies

**Settled by owner arbitration (2026-07-14):**

- **Retention:** hold until sync confirmed — note stays local until the Obsidian
  write is verified, then deletes.
- **Snooze:** kept in v1. Triage = Discard / Snooze / Keep.
- **Keep-for-export action name:** **Keep**.
- **Location precision:** **precise (GPS)**, not coarse.
- **Apple Notes:** intermediate build-order milestone only; not a shipped v1
  destination. Shipped destination is Obsidian only.
- **Pluggable seams:** clean internal boundaries only; no plugin system/config
  UI/plugin tests.
- **Auto-captured context:** time + location only for v1.
- **Launch model:** app root is **Triage**; **Capture sheet auto-presents on
  launch**. Capture is a presented modal sheet, not a tab/mode.
- **Capture surfaces:** required = in-app sheet; build one `CaptureNoteIntent`
  seam and validate the **Action button** as the single external surface for v1;
  all other external surfaces are v1.x. External capture does not gate v1.

**Remaining dependencies / open questions (owned elsewhere, not v1 scope
questions):**

1. **Obsidian write mechanism — tech-lead ADR (blocking).** How a sandboxed iOS
   app writes into the vault (share sheet vs. `obsidian://` vs. synced
   iCloud/Working Copy folder vs. git commit to the notes repo). **Blocking
   upstream dependency** for export UX *and* for the retention model: the chosen
   mechanism **must be able to confirm a successful write**, or "hold until sync
   confirmed" is not implementable. New hard requirement on the ADR.
2. **Snooze "session" definition — design-lead.** What starts/ends a triage
   session, and therefore when snoozed notes reappear (next app open / next
   calendar day / manual "start session"). Design decision, not a scope
   question.
3. **Precise-location consequences — design-lead + tech-lead.** Precise GPS is a
   heavier permission ask and a larger privacy surface. Needs a permission
   rationale/flow (design-lead) and correct entitlement handling + graceful
   permission-denied behavior (tech-lead).
4. **Precise-GPS-from-an-external-intent — tech-lead feasibility gate.** Whether
   a capture triggered from outside the app (Action button → `CaptureNoteIntent`)
   can reliably obtain precise GPS in that execution context. If it can't, the
   external-capture ambition is constrained: external captures may land without
   (or with degraded) location, which affects both the capture value and the
   frontmatter contract. Resolve before committing external-surface scope.
