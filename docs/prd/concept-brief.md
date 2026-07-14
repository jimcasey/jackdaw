# Jackdaw — Concept Brief

> **Status:** Seed input, not a finished PRD. This captures the owner's concept
> at the sharpening stage. Run `/prd` to have the product-lead turn it into a
> structured v1 PRD, resolve the open questions with the owner, and hand it to
> design-lead and tech-lead.

## What it is

Jackdaw is a personal iOS quick-capture inbox for fleeting notes.

Core identity: a **funnel into an external notes system (Obsidian), not an
archive**. Notes flow through three stages — **Capture → Triage → Export** — and
the app does not retain them as a destination.

Single user (the owner).

**Governing principle:** if a feature helps fast capture or clean handoff, it's
in scope; if it moves toward organizing, searching, or browsing past notes, it's
out of scope. This constraint is deliberate and is the main defense against
scope creep.

## Capture

Get a thought in with near-zero friction. On capture, automatically attach
whatever ambient context is available as metadata.

- **MVP:** a quick text note + time + location.
- **Architecture:** capture *sources* and context *providers* are pluggable
  extension points from day one. Ships with one source (text) and a minimal
  context set, but the seams exist so later additions don't require a rewrite.
- **Later (not MVP):** quick actions (e.g. "remember I visited the place at my
  current location"), share-sheet ingest from other apps (e.g. a restaurant
  shared from Apple Maps), implicit captures (e.g. ebook highlights made since
  the last session). Additional context providers (now-playing, weather) are
  the first tests of the context-provider seam.

## Triage

Batch review of the capture inbox. This is triage (fast keep-or-kill), **not**
sorting into categories or folders.

- Per note, the user can enrich or edit the attached context.
- Actions: **Discard** / **Snooze** (defer to the next session) /
  **Keep-for-export** (final action name TBD — candidates: Keep, Promote,
  Release).
- **MVP:** fully manual triage.
- **Later (not MVP):** deterministic or AI-assisted triage. The manual flow
  should not foreclose this.

## Export

Append refined note text to an external destination, then the app forgets it.

- Alongside the refined note, export a record of the original captured context
  (proposed mechanism: YAML frontmatter on the exported markdown).
- **MVP destination:** Apple Notes, chosen for ease of implementation — it lets
  us prove the capture/triage loop without solving the vault-write problem yet.
- **Must-have before v1 is "complete":** Obsidian markdown export.
- **Architecture:** destinations are pluggable. Further research needed on
  other destinations.
- **First ADR (blocking the export design):** how to write into an Obsidian
  vault from a sandboxed iOS app. Options to weigh: iOS share sheet, the
  `obsidian://` URL scheme, writing to a synced iCloud / Working Copy folder
  the vault picks up, or a git commit/push to the notes repo (the owner already
  keeps notes in a GitHub repo). Each has real tradeoffs; this shapes the
  export architecture and should be resolved before the walking skeleton.

## Open questions for the product-lead to resolve with the owner

- **Retention model after export:** delete immediately vs. brief hold vs.
  hold-until-sync-confirmed. (Affects how strictly "funnel not archive" is
  enforced in v1.)
- **"Session" definition** for Snooze: what starts and ends a triage session?
- **Keep-for-export action name:** Keep vs. Promote vs. Release.
- **MVP context sources:** confirm time + location only, deferring now-playing
  and weather to the context-provider seam.
- **Export mechanism:** the Obsidian-write decision above (own ADR via tech-lead).

## Owner's context (for tailoring)

- Notes are stored today in Obsidian vaults and a GitHub repo; the intent is to
  further refine exported notes with AI *outside* Jackdaw.
- Owner is a strong full-stack engineer, new to iOS specifically.