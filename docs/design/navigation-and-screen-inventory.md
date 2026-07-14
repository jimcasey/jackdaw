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

- **The app never opens onto a *growing* pile you browse.** Originally I read this as
  "Capture is home — launch to a blinking cursor." **That reading is now under
  revision** (see §2): if capture moves primarily *outside* the app (Action button /
  Siri / Control Center), the app's job becomes *processing*, not *capturing*, and
  opening to a Triage that is designed to **drain to empty** does not violate this
  rule — a shrinking work queue is not an archive. The load-bearing invariant is not
  "launch to Capture"; it is "**home is never a growing, browsable library.**"
- **There is no browsable history of past notes anywhere.** Not for exported notes
  (non-goal), not for snoozed notes, not in a "recently sent" view. The only list of
  note *content* in the entire app is the un-triaged Triage inbox. Everything
  downstream of a decision (kept/queued/exported) is surfaced as **status and
  counts, not as re-readable content.** This is the line I will defend hardest, and
  it is what keeps an open-to-Triage model honest.

---

## 2. Navigation model — REVISED (proposed, pending owner ratification)

> **Status:** The original two-tab model shipped a defect on device (below). This
> section proposes the fix. The in-app nav change (Triage-root + Capture-sheet) I
> recommend outright. The larger bet — *external capture as the primary trigger,
> app opens to Triage* — is framed as a **proposal for owner ratification**, because
> product-lead is ruling on scope in parallel and the bet depends on
> external-capture friction/feasibility that only on-device use (and tech-lead) can
> confirm.

### 2.0 The defect I own (was mislabeled an "honest wrinkle")

The original model launched the app to a keyboard-up **Capture tab**. I documented,
as an acceptable "wrinkle," that the always-up keyboard covers the iOS 26 floating
tab bar until you dismiss it. **On hardware that was a trap:** there was no obvious
way to dismiss the keyboard to reach Triage — the tab bar was simply unreachable.
That was a design defect, not a wrinkle, and I should have caught it. The owner
added a stopgap (keyboard "Done" + swipe-to-dismiss). The rethink below removes the
root cause rather than patching it.

**Root cause:** a *persistent tab bar* and a *persistent keyboard* competing for the
bottom edge, with no modal boundary between them. Any fix that keeps both persistent
is a patch. The real fix is to stop making Capture a *persistent* surface.

### 2.1 Recommended in-app model: Triage is the root; Capture is a modal sheet

**Drop the tab bar entirely.** The app becomes a **single navigation stack rooted in
Triage**, with:

- **Triage inbox as the root screen.** A `NavigationStack` list of un-triaged notes.
- **Capture presented as a modal *sheet*** — its own screen, its own keyboard, its
  own dismiss (swipe-down / a `Done` button). Invoked from a **prominent capture
  affordance** on the Triage screen (a large compose button — e.g. a bottom-docked
  "New note" button or a top-bar `square.and.pencil`).
- **Settings & Status** remains a sheet from a gear in the Triage nav bar (unchanged).

**How this fixes the keyboard/tab-bar trap — by construction:** a sheet *owns the
whole screen* and brings its own keyboard; there is **no tab bar underneath** to be
covered or to fight for the bottom edge. A keyboard filling the lower half of a
compose sheet is the completely standard, expected iOS combination (Mail compose,
Messages new message, Reminders new reminder). Dismissal is the universal sheet
gesture (drag down) *plus* an always-present `Done` button — so there is never a
state where the way out is hidden. The trap cannot recur because the two elements
that collided are no longer both persistent: capture is transient (a sheet),
processing is home.

This is also **better information architecture regardless of the external-capture
bet.** A tab implies *co-equal, persistent modes*. If capture is a quick action you
invoke and dismiss (and increasingly happens *outside* the app), then in-app capture
is an **action**, not a mode — and actions are modals/buttons, not tabs. HIG:
sheets are for self-contained tasks; tab bars are for top-level sections. Capture is
now the former.

### 2.2 The launch-destination question (the bet — for owner ratification)

Two options, depending on how good external capture proves to be:

- **(A) Launch to Triage-root (bare).** The app is the *processing* surface. You
  capture with the Action button / Siri / Control Center (§ capture-flows), and open
  the app to *clear the pile*. Recommended **iff** external capture is genuinely
  low-friction on this owner's device (see §2.3 risk).
- **(B) Launch to Triage-root with the Capture sheet auto-presented on top.**
  Preserves "open app → type immediately" (dismiss the sheet to land on Triage),
  while still fixing the keyboard/tab defect (it's a sheet, not a tab). A safe
  **transition default** if external capture isn't proven yet.

**My recommendation:** ship **(B) as the default now**, and move to **(A)** once the
owner confirms on-device that external capture (Action button / Siri) actually
replaces reaching for the app to type. Don't hard-commit to open-to-Triage-bare at
doc time; earn it with real usage. Either way the tab bar is gone and the defect is
fixed. Launch destination could even be a **setting** — but I'd resist shipping a
setting for something we can decide once we've felt it.

### 2.3 Where I disagree / the risk I want the owner to see

Making external capture *primary* is a real bet, and I'll say plainly where it could
go wrong on UX grounds:

- **The only no-launch *typed* path is the system text-prompt overlay** (Shortcuts
  "Ask for Input" / an App Intent's `requestValueDialog`) — a bare single-line-ish
  system field, not our editor. It's fine for a quick thought, but it is *not*
  richer than opening the app. If the owner finds "Action button → type in the
  system prompt → Done" no faster than "open app → type in the sheet," we've added
  surfaces without reducing friction.
- **Ambient location may be degraded in external capture** (see capture-flows § and
  the tech-lead question): the whole product promise is "context attached
  automatically." If a background App Intent can't reliably get a precise GPS fix,
  external captures are context-poor — a real cost to making them primary. **This is
  the sharpest open question and I want it answered before committing to (A).**
- **The Action button is one button (Pro models only) the owner may already use**,
  and Control Center is two gestures. These are good *accelerators*; I'm not yet
  convinced any of them beats a well-made in-app capture sheet for *typed* capture.

So: **fix the nav defect now (Triage-root + Capture-sheet, no tab bar) — that part
is unconditional.** Treat *external-primary / open-to-Triage-bare* as a proposal to
validate, not a settled decision. Deferring the primary-trigger call to the owner
after on-device validation and tech-lead feasibility.

---

## 3. Screen inventory

Legend — **HIG pattern** = the native idiom each screen uses; **A11y flags** =
the accessibility requirements that most affect *this* screen (full baseline in
`accessibility-and-hig.md`).

### Top-level (REVISED — Triage is now the root; Capture is a sheet)

| # | Screen | Role | HIG pattern | A11y flags |
|---|--------|------|-------------|-----------|
| 1 | **Triage inbox** | **Root / home.** Batch list of un-triaged notes; per-row Keep/Snooze/Discard + tap-to-edit. Carries the prominent **capture affordance** (compose button → Capture sheet) and a gear → Settings sheet. | `NavigationStack` root; `List` with leading/trailing **swipe actions**. | Swipe actions **must** be mirrored as VoiceOver custom actions + a context menu; state never by color alone; row height reflows with Dynamic Type; capture button ≥44pt + labeled. |
| 1a | **Triage empty state** | The default aspiration: "Inbox clear" + the capture affordance. When caught up, *this* is home — an empty workbench, not a pile. Snoozed notes acknowledged as a count only. | Standard empty-state (`ContentUnavailableView`) with a call-to-action. | Announce "Inbox clear" via VoiceOver; readable at accessibility text sizes. |
| 2 | **Capture (sheet)** | Invoked from the Triage capture button, or auto-presented on launch (option B), or deep-linked from an external trigger. Full-bleed **autosave** editor, own keyboard, own dismiss. **No Save button**; a **New note** control in the keyboard toolbar delimits one thought from the next. | **Modal sheet** (`.large` detent) with its own keyboard + `Done`/drag dismiss — the Mail/Messages/Reminders compose idiom. NOT a bordered textarea + submit button. | Dynamic Type in editor incl. accessibility sizes; New-note control ≥44pt + labeled; **`Done`/close reachable by VoiceOver (don't rely on drag-to-dismiss alone)**; no per-keystroke VoiceOver "saved" spam; capture haptic on New note. |

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

### External capture entry points (proposed — outside the app; see capture-flows §0)

All are powered by **one shared App Intent** (`CaptureNoteIntent`, `openAppWhenRun =
false`) so they are near-free once the intent exists. They deliver a quick text note
*without fully launching the app*:

| Surface | What the user does | Text entry mechanism | Native-ness |
|---------|--------------------|--------------------|-------------|
| **Action button** | one physical press | runs the intent / a Shortcut → system text prompt | highest (dedicated HW; Pro only) |
| **Siri / "Hey Siri"** | speak the note | intent `requestValueDialog` → **dictation** | highest (hands-free; a11y win) |
| **Control Center control** | swipe → tap | control runs the intent/Shortcut (text-prompt-from-control **needs tech-lead verification**; fallback = deep-link to the Capture sheet) | high (iOS 18+, all devices) |
| **Lock Screen control** | tap from lock/idle | same ControlWidget | high |
| **Home-screen quick action / Shortcuts widget** | long-press icon / tap widget | deep-link to Capture sheet, or a text-prompt Shortcut | medium |
| **Back Tap (accessibility)** | double/triple tap back | triggers the Shortcut | a11y bonus |

Widgets and Control Center controls **cannot host an inline text field** (buttons/
toggles only) — the only no-launch *typed* path is the system text-prompt overlay
(Shortcuts "Ask for Input" / `requestValueDialog`). Share Sheet is **out** (it's for
ingesting text *from* other apps — a PRD non-goal, not fresh capture).

### System-owned surfaces (we trigger, iOS renders)

- System **location permission** dialog (When-In-Use; precise). Purpose strings are
  tech-lead's Info.plist concern.
- System **document picker** for the vault folder grant.
- System **text-prompt overlay** for external no-launch capture (`requestValueDialog`
  / Shortcuts "Ask for Input").

Whole app (revised): **1 root (Triage) + 1 pushed editor + Capture sheet + 3
housekeeping sheets + external App-Intent surfaces + system dialogs.** No tab bar,
no history view, no archive, no folders, no search — by construction.

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
- **External capture (App Intent) is a tech-lead feasibility gate — held until after
  this report.** Three questions the whole external-primary bet rests on: (1) an
  `openAppWhenRun = false` intent that prompts for and persists text; (2) **whether
  that intent can obtain a precise GPS fix** when it runs outside the foreground app
  (extension/background) — this decides whether external captures keep the product's
  signature ambient location or degrade to timestamp-only; (3) whether a Control
  Center control can itself surface the text prompt or must route via Shortcuts /
  deep-link to the Capture sheet. Design recommends **(A) fix the nav defect now**
  (Triage-root + Capture-sheet, no tab bar — unconditional) and **(B) gate
  external-primary / open-to-Triage-bare on answers to the above + on-device
  validation.**
