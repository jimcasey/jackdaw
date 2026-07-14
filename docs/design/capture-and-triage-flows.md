# Jackdaw — Capture & Triage Flows

> **Status:** Draft for owner arbitration. Owned by design-lead.
> Reads with `navigation-and-screen-inventory.md`. The sharp open threads
> (snooze session, vault setup, re-grant, pending/failed, location permission)
> are broken out into `open-ux-threads.md`; this doc covers the two core flows.

Assumptions are called out inline as **[ASSUMPTION]** where the PRD/ADR is silent.

---

## 1. Capture flow

**Job:** get a thought out of my head in seconds, context attached automatically,
no filing decision, works offline.

### The flow

1. **Open app → Capture is already there.** Launch lands on Capture with the
   keyboard up and the cursor in the field. No tap needed to start typing.
2. **Type.** Full-bleed editor, generous margins, no visible container box.
   Placeholder: e.g. *"What's on your mind?"* Multi-line; `Return` inserts
   newlines (it does **not** save — text notes need line breaks).
3. **Save.** One explicit primary action commits the note. It is a button (a
   `Save` / up-chevron affordance in the top bar), **not** the Return key.
   - Save is **disabled while the field is empty** (no accidental blank notes).
4. **Context is attached silently.** On save we stamp the note with the capture
   **timestamp** and best-available **GPS location**. The user sees none of this
   during capture — no "attaching location…" spinner, no map. Context is ambient
   by design.
5. **After save: stay in Capture, field clears, ready for the next thought.** A
   brief, quiet confirmation (a subtle checkmark and/or a light save haptic). We
   do **not** navigate to Triage — capture stays capture, and rapid multi-capture
   is a first-class rhythm (throw in three thoughts in a row).
6. **Offline is a non-event.** The note is written to local storage regardless of
   network. Capture never depends on connectivity or on the vault being set up.

**Minimum-taps check:** app already open to Capture (keyboard up) → type → tap
Save. Effectively one tap beyond typing. Meets the mandate.

### GPS timing — the one real subtlety

A GPS fix can take a beat, and **capture must never wait on it.**

- **[ASSUMPTION]** We start a location request when the Capture screen appears, so a
  fix is usually ready by the time the user hits Save.
- If no fix is ready at save time, we **persist the note immediately** with
  timestamp + a "location pending" marker, and **backfill the coordinate within a
  few seconds** when the fix arrives. The note is never blocked.
- If location is denied/unavailable, the note saves with **timestamp only** and no
  location. No error, no nag on capture (see location thread).

> **Build dependency (tech-lead):** the capture write path must persist a note
> *before* a GPS fix exists and update it on backfill. This is a small state
> nuance (a note can briefly exist with `location: pending`) that the model must
> allow. Named so it's not a surprise.

### What I will insist is *native* here

This screen is the highest risk of coming out "web-shaped." Web instinct is a
bordered `<textarea>` with a floating "Submit" button. That is wrong on iOS. The
native form is a **full-bleed editor where the keyboard is the chrome** (Drafts,
Apple Notes new-note, Messages compose). No visible input border, no card, no
web-form submit button. If a comp shows a boxed textarea, that's the tell.

---

## 2. Triage flow

**Job:** come back later, review the batch, make a fast keep/kill decision per
note, lightly fix up keepers, drive the inbox to empty.

### Pattern: a `List` with swipe actions (Mail/Reminders idiom)

I considered a one-at-a-time **card stack** (Tinder-style). Rejected as the primary
pattern because:
- It hides the batch (you can't see how much is left → weaker "drive to zero" pull).
- Physics-y swipe stacks are a **reduced-motion and VoiceOver liability** and read
  as gimmicky/non-native.
- Editing mid-swipe is awkward.

The **`List` + swipe actions** pattern is the canonical iOS triage idiom (Mail,
Reminders): familiar muscle memory, shows the batch, swipe actions are first-class
and accessible, and editing is a clean tap-to-drill-in. That's the recommendation.

### The three actions, mapped to gestures

Each note is a row showing a text preview (first line or two) + a light context
line (relative time, and place name if present).

- **Leading swipe (swipe right) → Keep.** Green + checkmark SF Symbol. Full-swipe =
  Keep. Keep is the positive default, so it gets the "easy" leading full-swipe.
- **Trailing swipe (swipe left) → reveals Snooze + Discard.**
  - **Snooze** — amber + `moon.zzz` / clock symbol.
  - **Discard** — red + trash symbol. Full trailing-swipe = Discard (destructive).
- **Tap the row → Note editor** (light edit before deciding).
- **Long-press → context menu** with all three actions — a discoverable, fully
  accessible fallback that doesn't require knowing the swipe directions.

Color is never the *only* signal — every action carries an icon + label (colorblind
+ VoiceOver safe).

### Protecting the destructive action

Discard is irreversible and the funnel *promises* "discarded notes are gone." So a
full-swipe Discard fires immediately **but shows a brief inline "Note discarded —
Undo" banner** (a few seconds) so an accidental full-swipe is recoverable.

> **Native caveat (flagged):** iOS has no system "snackbar/toast." This undo banner
> is a **custom transient view** — it must use standard system materials, respect
> safe areas, and be announced to VoiceOver. It's the one non-stock component in
> triage; I'm accepting it because the alternative (losing a note to a fat-finger)
> violates the funnel's honesty promise. **Tech-lead may push back on the extra
> undo state** — teeing that up for the owner. (Keep, by contrast, is inherently
> recoverable: a kept note sits in the export queue and can be pulled back to the
> inbox until it's confirmed-exported, so it needs no undo banner.)

### Batch rhythm

- As each note is acted on, it **animates out of the list** (cross-fade under
  Reduce Motion) and the row below rises — a satisfying "clearing" cadence.
- The tab badge on Triage shows the **actionable-now count** (excludes not-yet-due
  snoozed notes — see snooze thread). Honest, but not a red alarm over hundreds:
  it's the standard tab count, and the design goal is to drive it to zero.
- **Empty state = the reward.** When the actionable inbox hits zero:
  *"Inbox clear."* If notes are snoozed for later, a single quiet line acknowledges
  them as a **count only** — e.g. *"3 will return in a later session"* — with **no
  affordance to open or browse them.** That absence is deliberate: snoozed notes are
  not a folder you rummage.

### Note editor (light editing)

Tapping a row **pushes** the editor onto the Triage nav stack (drill-in; back
returns to the list). Contents:

- **Text** — the same full-bleed editor as Capture, pre-filled and editable.
- **Context** section:
  - **Time** — editable via a system date/time picker. **[ASSUMPTION]** editable
    because captured time can be wrong (note typed later than the moment it
    describes); light context editing is explicitly in scope (PRD §4).
  - **Location** — a place name (reverse-geocoded for legibility) + a small static
    MapKit thumbnail. Must-have actions: **Clear location** and edit. A full
    "drop a pin on a map to correct it" affordance is **polish that can wait** — I'd
    cut it from v1 if it costs schedule; the must-have is view + clear + correct
    time. Flagged as cut-candidate, not core.
  - **No-location state** handled gracefully: no broken map, just *"No location."*
- **The three verbs live in a bottom bar** (Keep / Snooze / Discard) so you can act
  right after editing without going back. Acting returns you to the list and
  advances the rhythm.

**Push vs. sheet for the editor:** I chose **push** (part of the triage hierarchy,
keeps a linear list → note → back-to-list flow, and lets the three verbs sit
consistently at the bottom). A sheet is defensible (self-contained subtask) but
covers the list and loses the sense of place. Minor call; noting the alternative.

---

## 3. Flow summary (happy path, end to end)

1. Wild: open app → type → Save → (repeat). Notes queue locally with context.
2. Later: switch to **Triage** → swipe Keep / Snooze / Discard down the list,
   tapping in to fix up keepers → inbox reaches **"Inbox clear."**
3. Kept notes flow **automatically** into the export queue and are written to the
   Obsidian vault folder, verified, then deleted from Jackdaw (no per-note export
   step — that's the whole point of the T2 folder-write decision). Pending/failed
   states and first-run vault setup are covered in `open-ux-threads.md`.
