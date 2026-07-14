# Jackdaw — Capture & Triage Flows

> **Status:** Draft for owner arbitration. Owned by design-lead.
> Reads with `navigation-and-screen-inventory.md`. The sharp open threads
> (snooze session, vault setup, re-grant, pending/failed, location permission)
> are broken out into `open-ux-threads.md`; this doc covers the two core flows.

Assumptions are called out inline as **[ASSUMPTION]** where the PRD/ADR is silent.

---

## 1. Capture flow — autosave-as-you-type

**Job:** get a thought out of my head in seconds, context attached automatically,
no filing decision, works offline.

> **Model (owner-confirmed, overrides the earlier explicit-save flow):** Capture is
> **autosave-as-you-type**. There is **no Save/Done commit action.** A note persists
> continuously as it's typed, because the worst failure for a quick-capture funnel
> is losing a fleeting thought — autosave makes that structurally impossible.
> **Lazy creation:** a note comes into existence on the **first non-whitespace
> character** (not on opening Capture). **Prune-on-abandon:** an empty/whitespace
> note is discarded when the user leaves Capture, so fragments never reach Triage.

### The flow

1. **Open app → Capture is already there.** Launch lands on Capture with the
   keyboard up and the cursor in an empty field. No tap needed to start typing.
2. **Type — and it's already safe.** Full-bleed editor, generous margins, no
   visible container box. Placeholder: e.g. *"What's on your mind?"* Multi-line;
   `Return` inserts newlines. On the first non-whitespace character the note is
   created and thereafter every keystroke is persisted. There is **no Save button**;
   nothing the user does or forgets can lose the thought.
3. **Context is attached silently.** We stamp the note with the capture
   **timestamp** (at creation) and best-available **GPS location**. The user sees
   none of this while capturing — no "attaching location…" spinner, no map. Ambient
   by design.
4. **Start the next thought / leave.** See §1.1 — the key UX moment autosave
   creates. Rapid multi-capture (three thoughts in a row) stays a first-class
   rhythm; it's just delimited by an explicit **New note** action instead of a Save.
5. **Offline is a non-event.** Writes go to local storage regardless of network.
   Capture never depends on connectivity or on the vault being set up.

**Minimum-taps check:** app already open to Capture (keyboard up) → type. Zero taps
beyond typing to capture a single thought. Faster than the old explicit-save model.

### 1.1 The "I'm done — start the next one" moment (the key autosave question)

With no Save button, we lose the thing that used to delimit one note from the next.
Autosave answers *"is it safe?"* but creates a new question: *"when does this note
end and the next begin?"* Two distinct exits, both defined here so the tech-lead
can align the mechanism:

**Exit A — I'm leaving Capture** (switch to Triage, background the app, or the app
is closed). The note is already persisted; **leaving is the commit.** No action
needed. The moment you leave Capture with content, that thought is in the funnel and
will appear in the Triage inbox. If the field is empty/whitespace on leave, it's
**pruned** (never reaches Triage).

**Exit B — I want to capture another thought right now** (rapid multi-capture,
staying in Capture). This needs an explicit delimiter, because if the user just
keeps typing it all becomes *one* note. That delimiter is a **"New note" action:**

- It is **not a Save** — the current note is already saved. It means *"bank this one
  and give me a fresh field."*
- On tap: the current note stays committed in the funnel, the field **clears to a
  new empty note**, the keyboard stays up, cursor ready. A brief, quiet confirmation
  (light haptic + a short *"Captured"* micro-confirmation as the field wipes) marks
  the hand-off. This is the moment that gives the "one thought done, next thought"
  rhythm the Save button used to provide.
- **Placement: a keyboard toolbar (input accessory view), thumb-reachable while
  typing** — not a top-bar button. Capture is one-handed with the keyboard up, so
  the New note affordance belongs at the bottom near the thumb, not at the top-right
  reach. This keeps the editor itself completely full-bleed and chrome-free.
- **Disabled/absent while the field is empty** (nothing to bank yet). Its
  *appearance* once you've typed doubles as the ambient "you've captured something"
  signal — see §1.2.

**Re-entry rule (funnel discipline): Capture always opens on a fresh empty note —
it never resumes a previously captured note.** If you typed "buy milk," left, and
come back, you get a blank field, not "buy milk" again. That note is now in Triage;
continuing to edit it happens **in Triage**, not Capture. This is the line that
keeps Capture from drifting into an editor/notepad: Capture is *fast in, gone to
Triage*, never a place you browse or resume drafts.

> **Owner call to be aware of (flagged, not blocking):** the re-entry rule means a
> quick app-background mid-sentence commits that in-progress note to Triage; on
> return you get a fresh field, and the half-typed thought is waiting in the inbox
> rather than still under the cursor. This is the correct funnel behavior and keeps
> the model dead-simple ("leaving Capture = it's in the inbox"), but it can feel
> like the app "moved" your note after a 2-second glance-away. I recommend accepting
> it for simplicity; if it grates in real use, the softener is to resume the
> in-progress note only when returning within a short window. Not pre-building that.

### 1.2 What the user sees/feels with no Save button

The design risk of autosave is a *trust* gap: without a Save button, does the user
believe the thought is safe? And a *noise* risk: a Google-Docs-style
"Saving…/Saved" that flickers per keystroke would be un-native and, worse, VoiceOver
spam. Resolution:

- **No per-keystroke save indicator.** Saving is continuous and reliable; announcing
  it constantly is web-app noise. Trust is built by the model being *actually*
  lossless, reinforced by two calm, static signals:
  1. The **New note** affordance appearing in the keyboard toolbar once a note
     exists — its presence means "you have a captured note here."
  2. **[ASSUMPTION — tunable]** an optional, subtle, *static* "Saved" label beside
     it (a state, not a per-keystroke event). I lean minimal: ship the New-note
     affordance first; add the "Saved" label only if the owner wants extra
     reassurance early. It's reassurance polish, not core, and can be removed once
     the model is trusted.
- **Pruning is silent.** An abandoned empty note vanishing needs no confirmation — it
  was never a thought.

### 1.3 Prune triggers — the exact UX definition (tech-lead aligns to this)

Design owns *when* a note is pruned; naming it precisely so the mechanism matches:

- **Prune is evaluated when the user *leaves* Capture** — tab switch to Triage, app
  background/suspend, or app close. If, at that moment, the current note is
  empty/whitespace-only, it is discarded and never created/never reaches Triage.
- **Clearing the field while *staying* in Capture does NOT prune mid-session.** If
  you delete everything back to empty but remain on the screen, typing again
  continues the *same* note (it hasn't been abandoned — you haven't left). It's
  pruned only if you then leave while still empty. This avoids a jarring "note
  destroyed while I'm still looking at it."
- **Tapping New note with an empty field is a no-op** (nothing to bank; you're
  already on a fresh note).
- Net: the **only content-destroying paths in the whole app are Discard (in Triage)
  and confirmed-export-delete.** Prune only ever removes *empties*. No real thought
  is ever lost by prune — consistent with the whole point of autosave.

### GPS timing — the one real subtlety

A GPS fix can take a beat, and **capture must never wait on it.**

- **[ASSUMPTION]** We start a location request when the Capture screen appears, so a
  fix is usually ready by the time a note is created.
- If no fix is ready when the note is created, we persist the note immediately with
  timestamp + a "location pending" marker, and **backfill the coordinate within a
  few seconds** when the fix arrives. The note is never blocked.
- If location is denied/unavailable, the note carries **timestamp only** and no
  location. No error, no nag on capture (see location thread).

> **Build dependency (tech-lead):** the capture write path must persist a note the
> instant it has content, *before* a GPS fix exists, and update it on backfill (a
> note can briefly exist with `location: pending`). Under autosave this is the
> steady state, not an edge case — every note is persisted-then-enriched.

### What I will insist is *native* here

This screen is the highest risk of coming out "web-shaped." The web instinct is a
bordered `<textarea>` with a floating "Submit" button — doubly wrong now that there
is no submit at all. The native form is a **full-bleed editor where the keyboard is
the chrome** (Drafts, Apple Notes new-note, Messages compose), with the single
**New note** control living in the keyboard toolbar. No visible input border, no
card, no web-form submit button. If a comp shows a boxed textarea or a Save CTA,
that's the tell.

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
>
> **Autosave strengthens this argument (Slice 4 fork — flagged, not resolved
> here).** Under autosave-as-you-type, *every* note in Triage is a real, persisted
> thought from its first character — there is no "unsaved draft" limbo where a note
> is only half-real. So a mis-tapped Discard destroys genuine captured data, full
> stop. The owner adopted autosave precisely to make *losing a thought structurally
> impossible* in Capture; leaving Triage's one-tap Discard unrecoverable would
> reintroduce exactly that failure at the other end of the funnel — an inconsistency.
> Prune, by contrast, only ever deletes empties, so Discard is now the *sole* place a
> real thought can be lost by a single tap. That makes the undo banner more
> compelling, not less. **Still the owner's call at Slice 4** — I'm only recording
> that the autosave decision moved the evidence toward "keep the undo."

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

1. Wild: open app → type (autosaved instantly) → **New note** to bank it and start
   another, or just leave. Notes queue locally with context; empties are pruned.
2. Later: switch to **Triage** → swipe Keep / Snooze / Discard down the list,
   tapping in to fix up keepers → inbox reaches **"Inbox clear."**
3. Kept notes flow **automatically** into the export queue and are written to the
   Obsidian vault folder, verified, then deleted from Jackdaw (no per-note export
   step — that's the whole point of the T2 folder-write decision). Pending/failed
   states and first-run vault setup are covered in `open-ux-threads.md`.
