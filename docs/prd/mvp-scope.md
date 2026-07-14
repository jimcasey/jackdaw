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
   decision at capture time.
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

**Capture**
- A single capture surface: **text note**, opened and typed with minimum taps.
- Automatic context on capture: **timestamp** and **coarse location**.
- Capture works **offline**; notes queue locally.

**Triage**
- A **batch inbox** view of un-triaged notes.
- Per note, three actions: **Discard**, **Snooze** (defer to next session),
  **Keep-for-export**.
- Per note, **edit the note text** and **edit/correct the attached context**
  before keeping.

**Export**
- Export kept notes to **Obsidian** as markdown files, with captured context
  written as **YAML frontmatter**.
- After a confirmed export, the note **leaves the app** (retention model — see
  Open Questions).

**Cross-cutting**
- Single user, single device. No account, no sync, no multi-device story.

> **Scope stance on "pluggable seams":** v1 ships **exactly one** capture source
> (text), **one** context set (time + location), and **one** export destination
> (Obsidian). Internal boundaries that keep those from being hard-wired
> spaghetti are good engineering and welcome — but *building, testing, or
> designing UI for a plugin system, a second source, or a second destination is
> a non-goal.* The seam is a code-hygiene decision for tech-lead, not a v1
> feature. See non-goals.

## 5. Explicit non-goals (v1 deliberately does NOT do)

- **No browsing, searching, or re-opening exported notes.** Once a note leaves,
  it's gone from Jackdaw. There is no history, archive, or "recently exported."
- **No organizing:** no folders, tags, categories, notebooks, or sorting during
  triage. Triage is keep/kill/snooze only.
- **No Apple Notes destination.** The concept brief floated Apple Notes as an
  easier stepping stone. Product position: Apple Notes delivers **zero user
  value** for this user (their vault is Obsidian) and would be throwaway work.
  It may still earn its place as a *tech-lead de-risking stub* inside the
  walking skeleton — but it is **not a shipped v1 destination**. (Tee up for
  owner — see below.)
- **No AI or automated triage.** Triage is fully manual in v1.
- **No pluggable-source or pluggable-destination product feature** (see scope
  stance above). No share-sheet ingest, quick actions, or implicit captures.
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

## 7. Open questions (owner decisions needed)

1. **Retention model after export.** Delete immediately vs. brief hold vs.
   hold-until-sync-confirmed. Recommendation: at minimum, hold until the export
   write is *confirmed* (guards against silent data loss into the vault), then
   delete. "Funnel not archive" argues against any user-visible hold. Needs
   owner call once tech-lead scopes the Obsidian write path.
2. **"Session" definition for Snooze.** What starts/ends a triage session, and
   therefore when a snoozed note reappears? Options: next app open, next
   calendar day, or a manual "start session." *Sub-question: is Snooze even
   needed in v1, or is Discard/Keep enough?* Snooze adds a note state and reentry
   rules; product-lead leans toward **cutting Snooze from v1** unless the owner
   knows they'll want it. (Tee up for owner.)
3. **Keep-for-export action name.** Keep vs. Promote vs. Release. Naming, not
   scope — but sets the app's vocabulary. Product-lead leans **Keep**.
4. **Confirm context set = time + location only** for v1, deferring everything
   else to the (non-feature) seam.
5. **Obsidian write mechanism.** How a sandboxed iOS app writes into the vault
   (share sheet vs. `obsidian://` vs. synced iCloud/Working Copy folder vs. git
   commit to the notes repo). This is a **tech-lead ADR** and is blocking for
   export design; product-lead only needs the outcome to confirm the export UX.
6. **Coarse vs. precise location.** Coarse is cheaper on permissions and privacy
   and is likely enough for "where was I." Confirm coarse is acceptable, or
   whether precise adds real value to the notes.
