# Jackdaw — Navigation Model & Screen Inventory

> **Status:** Draft for owner arbitration. Owned by design-lead. Hangs off
> `docs/prd/mvp-scope.md` (scope source of truth) and
> `docs/adr/0001-obsidian-write-mechanism.md` (T2 folder-write → the setup,
> re-grant, and pending/failed surfaces here flow from that ADR).
>
> Companion docs: `capture-and-triage-flows.md`, `open-ux-threads.md`,
> `accessibility-and-hig.md`.

This doc defines the spine: how many "places" the app has, how you move between
them, and every screen in v1. Flows live in the companion docs.

---

## 1. Design north star: the navigation must not invite browsing

The governing principle (funnel, not archive) is a **navigation constraint**, not
just a feature-list constraint. Most notes apps make *the list of notes* the home
screen. That single decision is what turns a capture tool into a pile you browse.
Jackdaw must not do that. Two rules fall out of it:

- **Capture is home.** The app launches straight into a blank capture surface with
  the keyboard already up. This is the near-zero-friction mandate (PRD success
  criterion #1) and it also means the app never opens *onto the pile*. This mirrors
  Drafts, the closest-in-spirit iOS app: it opens to a blinking cursor, not a list.
- **There is no browsable history of past notes anywhere.** Not for exported notes
  (non-goal), not for snoozed notes, not in a "recently sent" view. The only list of
  note *content* in the entire app is the un-triaged Triage inbox. Everything
  downstream of a decision (kept/queued/exported) is surfaced as **status and
  counts, not as re-readable content.** This is the line I will defend hardest.

---

## 2. Navigation model: a two-tab tab bar

**Recommendation: a `TabView` with exactly two tabs — `Capture` and `Triage` —
plus a Settings/Status surface presented as a *sheet*, not a third tab.**

### Why a tab bar (HIG reasoning, for an iOS newcomer)

Apple's HIG is explicit that a **tab bar is for switching between the top-level
sections of an app** — peer areas the user moves between — and is *not* for
triggering one-off actions or holding settings. (iOS 26 reiterated this when it
restyled tab bars as floating "Liquid Glass" surfaces.)

Jackdaw genuinely has **two co-equal modes used at different times**:

- **Capture** — done in the wild, one-handed, in seconds, often distracted/offline.
- **Triage** — done later, in a deliberate sit-down, to clear the inbox.

Two modes, used at different times, switched between freely = the textbook case for
a tab bar. HIG allows 2–5 tabs; two is legitimate and maximally legible, which
suits an owner new to iOS.

### Why the third "place" (Settings/Status) is a sheet, not a tab

Vault setup, re-grant, export status, and permission state are **housekeeping**, not
a mode you *work in*. Putting them in the tab bar would (a) violate the HIG rule
(tab bars aren't for settings) and (b) dilute the funnel's two-verb clarity. They
live behind a gear in the Triage nav bar and open as a **sheet** — the HIG pattern
for a self-contained subtask you dip into and dismiss.

### Launch behavior (deliberate, not "restore last tab")

**Always launch to Capture with the keyboard raised** — never restore the
last-used tab. Restoring the last tab would sometimes open the app onto the Triage
pile, which fights both the friction mandate and the funnel ethos. Capture is the
priority job every single launch.

### Alternative considered and rejected

**Capture as a full-screen root, Triage reached by pushing a navigation
destination.** More funnel-pure (you *deliberately go* review), but less
discoverable, makes Triage feel like a child of Capture (it isn't), and is a less
conventional pattern for an iOS newcomer to reason about and maintain. The tab bar
gets the same funnel protection cheaply via launch-to-Capture + no-history, so the
extra opinionation isn't worth the discoverability cost. Flagging it so the owner
sees the fork; I can switch if the owner wants maximum funnel purity over
convention.

### One honest wrinkle (keyboard vs. floating tab bar)

At launch, the keyboard is up on Capture, so the floating tab bar sits *behind* the
keyboard and isn't tappable until the keyboard is dismissed (swipe-down / Done).
This is fine and consistent with Messages/Mail (their bottom chrome hides behind the
keyboard too): to *leave* focused capture you first dismiss the keyboard, which
reveals the tab bar. Documented so it reads as intentional, not a bug.

---

## 3. Screen inventory

Legend — **HIG pattern** = the native idiom each screen uses; **A11y flags** =
the accessibility requirements that most affect *this* screen (full baseline in
`accessibility-and-hig.md`).

### Top-level

| # | Screen | Role | HIG pattern | A11y flags |
|---|--------|------|-------------|-----------|
| 1 | **Capture** | Launch/home. Full-bleed **autosave** editor, keyboard up, context attached silently. **No Save button** (autosave-as-you-type); a **New note** control in the keyboard toolbar delimits one thought from the next. | Full-screen content view; keyboard is the primary chrome (like Drafts/new Apple Note). NOT a bordered textarea + submit button. | Dynamic Type in editor incl. accessibility sizes; New-note control ≥44pt + labeled; no per-keystroke VoiceOver "saved" spam; capture haptic on New note. |
| 2 | **Triage inbox** | Batch list of un-triaged notes; per-row Keep/Snooze/Discard + tap-to-edit. | `List` with leading/trailing **swipe actions**; nav stack root; nav-bar gear → Settings sheet. | Swipe actions **must** be mirrored as VoiceOver custom actions + a context menu; state never by color alone; row height reflows with Dynamic Type. |
| 2a | **Triage empty state** | The reward: "Inbox clear." Notes snoozed-until-later acknowledged as a count only. | Standard empty-state (`ContentUnavailableView`). | Announce "Inbox clear" via VoiceOver; readable at accessibility text sizes. |

### Pushed within Triage

| # | Screen | Role | HIG pattern | A11y flags |
|---|--------|------|-------------|-----------|
| 3 | **Note editor** | Light edit of a note before deciding: text + captured context (time, location). Carries the three triage verbs. | **Push** in the Triage nav stack (drill-in). Text field + a "Context" section (date/time picker, location row w/ static map thumbnail). Actions in a bottom bar. | Map thumbnail needs a text alternative (place name); "No location" state must be handled; pickers are system controls (already accessible). |

### Presented as sheets (housekeeping — not tabs, not history)

| # | Screen | Role | HIG pattern | A11y flags |
|---|--------|------|-------------|-----------|
| 4 | **Settings & Status sheet** | Vault status/setup, re-grant, export status (pending/failed), location status. | Modal **sheet** from the Triage gear. Grouped `List`/`Form`. | Every status row conveys state in text + icon, not color; Retry ≥44pt. |
| 5 | **Vault setup sheet** | One-time "choose your Obsidian vault folder." | Short explainer → system **document picker** (folder mode). Never a custom file browser. | Explainer legible at large sizes; single clear primary button. |
| 6 | **Location priming sheet** | In-context rationale shown *before* the system location prompt. | Small explanatory sheet → then the system `CLLocationManager` prompt. | Plain-language rationale; not blocking first capture (see flows). |

### System-owned surfaces (we trigger, iOS renders)

- System **location permission** dialog (When-In-Use; precise). Purpose strings are
  tech-lead's Info.plist concern.
- System **document picker** for the vault folder grant.

That's the whole app: **2 tabs, 1 pushed editor, 3 sheets, 2 system dialogs.** No
history view, no archive, no folders, no search — by construction.

---

## 4. Where this constrains / depends on the build (for the owner + tech-lead)

- **Vault setup (screen 5) must exist before export can be exercised.** This aligns
  with ADR gate 2a (the walking skeleton's first proof-point is pick-folder →
  persist bookmark → resolve on cold launch → write+verify). Design and skeleton
  meet here: the setup sheet *is* the UI for that gate.
- **The Settings/Status sheet (screen 4) and re-grant surface depend on the export
  subsystem exposing state.** For the status/re-grant UI to be honest, Talon /
  the retention state machine must surface, per queued note: current state
  (`pending`/`writing`/`failed`/`confirmed`), a **failure reason** (offline vs.
  access-lost vs. write-error), a **count**, and a **retry** trigger. Named so the
  design/build seam is explicit. Detail in `open-ux-threads.md`.
- **Capture must persist the note independent of a GPS fix** (async backfill) — see
  flows. This is a constraint on the capture write path.
