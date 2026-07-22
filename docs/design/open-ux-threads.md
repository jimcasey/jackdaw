# Jackdaw — Open UX Threads

> **Status:** Draft for owner arbitration. Owned by design-lead. These are the
> sharp threads the settled decisions created. Each states a recommendation, the
> assumptions behind it, the build dependency, and where I expect push-back.
> Reads with `navigation-and-screen-inventory.md` and
> `capture-and-triage-flows.md`.
>
> **Update (2026-07-22):** these threads are **largely resolved and shipped** — they
> drove the v1 design. This doc is retained as **design rationale** (the "why"), not as
> a live backlog. The residual *open* items have moved to GitHub Issues: the snooze
> anti-graveyard nudge (#22) and midnight-boundary refinement (#23) from Thread 1, and
> the per-note stuck-list fallback (#20) from Thread 4.

The five threads: **snooze-session model**, **first-run vault setup**, **vault
re-grant recovery**, **pending/failed export surfacing**, **precise-location
permission flow**.

---

## Thread 1 — Snooze-session model (this one is mine to propose)

**Context:** product-lead wanted Snooze cut; the owner kept it. So Snooze has to
*earn its place* with a model crisp enough that it can't quietly become an
infinite-deferral graveyard — which would be archive creep wearing a Snooze hat.

### The question the PRD hands me

What starts/ends a triage "session," and therefore **when do snoozed notes
reappear** — next open / next calendar day / manual "start session"?

### Recommendation

**Snooze means "not this sitting — bring it back next time I sit down, later."**
Concretely:

- **A triage session is a single sitting.** It has no visible "Start session"
  button — ceremony would add friction to a flow that's meant to be a calm
  sit-down.
- **Snoozing a note hides it for the rest of the current sitting** (so you can't
  churn the same note over and over in one pass — that's the anti-graveyard guard).
- **Snoozed notes reappear in the inbox at the first Triage open on a *later
  calendar day* than they were snoozed.** Simple, predictable, gives real
  breathing room ("sleep on it"), no button, and it structurally prevents
  same-sitting churn.
- **Snoozed notes are never browsable.** There is no "Snoozed" list/folder to open
  and rummage — that would be an archive. They are simply *absent* from the inbox
  until due, then they rejoin it. The only acknowledgment of their existence is the
  count-only line in the empty state (*"3 will return in a later session"*).
- **Snoozed notes do not count in the Triage tab badge** until they're due. The
  badge = actionable-now.
- **Anti-graveyard guard (proposed):** track a per-note snooze count and *surface*
  it once a note has been snoozed repeatedly (e.g. after 3×, the row reads
  *"snoozed 3×"* and is styled to nudge a decision). I recommend **surfacing, not
  hard-disabling** Snooze — hard-disabling would force a rushed Keep/Discard, which
  is worse. The nudge keeps Snooze honest without trapping the user.

### Why calendar-day over the alternatives

- **Next app open** — too soon and muddy: every launch opens Capture, and a note
  you just snoozed would be back almost immediately. Rejected.
- **Manual "start session"** — explicit and unambiguous, but adds a mode and a tap
  to every triage sitting. For a single, technically-fluent owner doing deliberate
  sit-downs, the implicit rule reads more naturally ("bring it back later") without
  ceremony. Rejected as primary; could be revisited if the owner *wants* explicit
  control.
- **Next calendar day (chosen)** — dead simple to explain and implement,
  predictable, real breathing room, resists churn.

### [ASSUMPTION] + refinement offered

- **[ASSUMPTION]** "Later calendar day" is measured in the device's local time
  zone. Known edge case: snoozing at 11:58pm returns the note ~2 minutes later. For
  a single user this is negligible; if it ever grates, the drop-in refinement is
  *"reappears after the next local 4am boundary, or ≥6h elapsed, whichever is
  later,"* which kills the midnight edge without adding UI. I'm defaulting to the
  simplest rule and flagging the refinement rather than pre-building it.

### Build dependency (tech-lead)

- Each note needs a `snoozedUntilDate` (or a `snoozedOnDay` + a "due when day >
  that") and a `snoozeCount`. The inbox query is "un-triaged AND (not snoozed OR
  snooze-due)." No new screens — Snooze is a state transition, not a place.

### Where I expect push-back

- **Product-lead:** may still argue Snooze (and especially the snooze-count nudge)
  is complexity that earns its keep only marginally. My defense: the model adds *no
  screen and no browsable surface*; it's one state field and one query clause, and
  the count-nudge is what stops it from becoming the pile product-lead fears.
  Deferring the final keep/cut of the *count-nudge* specifically to the owner.

---

## Thread 2 — First-run vault-folder setup

**Context (from ADR 0001, T2):** the owner picks the Obsidian vault folder once via
the system document picker; we persist a security-scoped bookmark and thereafter
write into it. Must feel like reasonable setup, not friction, in a tool that
prizes zero-friction capture.

### Recommendation: lazy, in-context setup — never a front-loaded wizard

- **First launch drops straight into Capture** (keyboard up). We do **not**
  front-load a setup wizard. The user's first experience must be the core magic —
  throwing a thought in — not a configuration chore. I will defend this hard: a
  setup gate on first launch is exactly the web-onboarding instinct that would
  betray this app's identity.
- **Capture has zero dependency on the vault.** You can capture for days without
  ever picking a folder. Setup is only needed before a note can *export*.
- **Setup is triggered the first time it's actually needed** — the first time the
  user **Keeps** a note (the first moment a vault is required). At that point we
  present the **Vault setup sheet**:
  1. One line of *why*: *"Jackdaw writes your kept notes as markdown files into
     your Obsidian vault."*
  2. One line of *what to pick*: *"Choose your Obsidian vault folder — usually On My
     iPhone → Obsidian → <your vault>."*
  3. Primary button **"Choose Vault Folder"** → the **system document picker**
     (folder mode). Native, no custom file browser.
  4. On pick: persist the bookmark, **write+read a probe file to verify
     writability** (this is also ADR gate 2a), then confirm: *"Vault connected."*
- **Keeping is never blocked by missing setup.** If the owner dismisses setup and
  keeps notes anyway, those notes sit in the export queue as `pending`; once the
  vault is connected the queue flushes automatically. So the funnel keeps working;
  setup just unblocks the *exit*.

### [ASSUMPTION]

- Exactly **one** vault (single user, single destination per PRD). No
  vault-switching UI (that's config UI, a non-goal). Changing the folder later
  happens through the same picker via the re-grant/Settings path — not a
  first-class "manage vaults" feature.

### Build dependency (tech-lead)

- This sheet **is** the UI for ADR gate 2a (pick folder → persist bookmark →
  resolve on cold launch → write+verify). Design and walking-skeleton meet here —
  the skeleton's first proof-point and this screen are the same deliverable.

### Where I expect push-back

- **Tech-lead** may prefer to build setup as a simple first-run gate (cheaper: no
  "keep-triggered" trigger, no pending-before-setup path). I'm holding the line on
  lazy/in-context because a front-loaded gate damages the first-run magic and the
  friction promise. Teed up for the owner.

---

## Thread 3 — "We lost vault access — re-grant" recovery

**Context (from ADR 0001 Consequences):** security-scoped bookmarks go stale (OS
updates, vault moved). `bookmarkDataIsStale` on resolve, or an access failure at
write time, means we can't write until the owner re-grants. Graceful recovery is
*required, not optional* (ADR).

### Recommendation

- **No data loss, ever.** On a stale/failed bookmark, affected notes simply stay in
  the export queue (`pending`/`failed` per the retention state machine). Nothing is
  dropped; the funnel just can't complete the exit until access is restored.
- **Surface it where it's actionable, not where it interrupts.** Capture is
  independent of the vault, so we **never** interrupt Capture with this. The
  re-grant surfaces:
  - As a **non-blocking banner in Triage / the status area**: *"Lost access to your
    vault. Re-grant to resume exporting."* Tapping opens the same document-picker
    flow (re-pick the folder) → re-persist bookmark → flush the queue.
  - As a **status row in the Settings & Status sheet**: *"Vault: access lost —
    Re-grant."*
- **Tone: routine re-confirmation, not user error.** Copy frames it as *"iOS
  occasionally needs you to re-confirm folder access,"* not *"Error: access
  denied."* The owner didn't break anything; the OS expired a token.

### Build dependency (tech-lead)

- The export subsystem (Talon) must distinguish **access-lost** from other failure
  reasons and expose that signal, so the UI can show *re-grant* (routes to the
  picker) rather than a generic *retry*. This is the same failure-reason enum the
  pending/failed surface needs (thread 4).

---

## Thread 4 — Pending / failed export surfacing

**Context:** retention = "hold until sync confirmed," so notes legitimately sit in
`pending` (offline / awaiting write) or `failed` (write error). The honest model
*surfaces* "this note hasn't made it out yet." The owner explicitly named this as
**friction the confirmation requirement forces in** — design it deliberately so it
informs without becoming an archive/inbox-of-shame.

### The core design line: status, not content

The export queue is **status and counts, not re-readable/re-organizable content.**
That single rule is what keeps it from becoming a second inbox or an archive:

- **Kept notes leave the Triage inbox immediately** — a decided note is gone from
  triage, so Keep still *feels* like "handled." It moves to the export queue.
- The queue surfaces as **state + count**, primarily in the **Settings & Status
  sheet**: *"Export: 2 pending · 1 failed."*
- **Pending (offline) is the normal, calm state — not an error.** It's presented
  quietly (*"Waiting to sync — offline"*) and flushes automatically when
  connectivity/access returns. No action needed, so it gets **no loud badge**; it
  lives in the status sheet, not in your face.
- **The loud state is only "failed" or "access lost"** (actionable). When one
  exists, a subtle indicator appears in the Triage nav bar (a small up-arrow/cloud
  glyph + count) — informative, not alarming — and the Settings sheet offers
  **Retry** (or, for access-lost, **Re-grant** → thread 3).
- **Minimal per-note visibility, deliberately capped.** The status sheet *may* list
  each queued note as **a truncated first line + state + time**, with **Retry**
  (failed) and **"Return to inbox"** (send a failed note back to Triage to re-edit
  or re-decide). It shows **no full bodies, no editing in place, no search, no
  sort.** Just enough to identify and act. This is the deliberate, minimal friction
  the retention model forces — no more.
- **The queue self-empties and disappears.** When it drains, the section is gone.
  **There is never an "exported" / "recently sent" view** — once a note is
  confirmed it's deleted and vanishes (non-goal guardrail). The funnel stays empty
  and honest.

### Why this doesn't become an inbox-of-shame

Two levers: (1) the *normal* state (pending/offline) is quiet, so day-to-day you
don't see a guilt pile — only genuinely-stuck notes shout; (2) there is no browsing
of successfully-exported notes and no sort/organize, so the surface can't grow into
a place you *tend*. It informs, then empties.

### Build dependency (tech-lead) — the shared seam

For this surface to be honest, the retention state machine / Talon must expose, per
queued note:
- **state** (`pending` / `writing` / `failed` / `confirmed`),
- **failure reason** (offline vs. access-lost vs. write-error) — drives whether the
  UI shows *Retry* vs. *Re-grant*,
- a **count** by state (for the status line and the nav-bar indicator),
- a **retry** trigger and a **return-to-inbox** transition.

This is the same signal set thread 3 needs. Named as the single design/build seam
where my status surfaces meet the tech-lead's state machine.

### Where I expect push-back

- **Product-lead** may read even the capped per-note list as archive-adjacent. My
  defense: it's status not content, it's capped to identify-and-act, it self-empties,
  and it exists only because the *owner's* "hold until sync confirmed" decision
  makes "did it actually leave?" a real question the user is entitled to answer. If
  the owner wants it leaner, the fallback is **counts-only, no per-note list** — I'd
  accept that as long as `failed` notes still have a path back to the inbox.

---

## Thread 5 — Precise-location permission flow

**Context:** the owner chose **precise (GPS)**, not coarse. That's a heavier
permission ask and a bigger privacy surface. Needs an in-context rationale and a
graceful permission-denied fallback — capture must still work.

### Recommendation

**Authorization level: When-In-Use, precise — not Always.** Capture is always
foreground in v1; there is no background capture, so **Always** would be a heavier,
creepier ask with zero benefit. I'll insist on **When-In-Use** — better privacy
hygiene and a lower-friction grant. (Tech-lead owns the entitlement/Info.plist
purpose strings.)

**Ask in context, primed, and never blocking the first capture:**

- **Don't ask at first launch.** HIG (and common sense) say request permission when
  the value is obvious, not cold on launch.
- **The very first capture is never interrupted.** The text field is live
  immediately. We show a lightweight **location priming sheet** *before* the system
  dialog (so the system prompt isn't a cold surprise), timed so it doesn't
  interrupt typing — it appears when the owner **saves their first note** (or a beat
  after the Capture screen settles if they haven't started typing). Priming copy:
  *"Jackdaw attaches where you were to each note, so a fleeting thought keeps its
  context. Location stays on your notes and is sent only to your Obsidian vault."*
  → **Continue** triggers the system `CLLocationManager` prompt.
- If they save that first note before granting, it attaches **timestamp only**
  (honest); subsequent notes get GPS once granted. The #1 job (capture) is never
  gated on a permission decision.

**Handle the precise-vs-reduced wrinkle (iOS 14+):** a user can grant location but
with **Precise Location OFF** (`accuracyAuthorization == .reducedAccuracy`). Coarse
location defeats the "where *exactly* was I" value the owner deliberately chose. So:

- If we get `reducedAccuracy`, show a **one-time, gentle** note explaining precise
  matters here, and offer to request temporary full accuracy via
  `requestTemporaryFullAccuracy(purposeKey:)` (purpose string in
  `NSLocationTemporaryUsageDescriptionDictionary`), or deep-link to Settings to
  enable Precise Location.
- **Do not nag repeatedly.** Surface it once; thereafter it lives quietly in the
  Settings sheet as a location-status row. Reduced accuracy still produces a usable
  note — we inform, we don't block.

### Permission-denied fallback (capture must still work)

- **Denied/restricted → capture works fully**, attaching **timestamp only**, no
  location. **No error and no nag on every capture** — that would punish the user
  for a valid choice.
- Surface the denied state **once, calmly**, in the Settings sheet: *"Location off —
  notes won't include where you were. Turn on in Settings,"* with a deep-link to the
  system Settings.
- Downstream, the note editor and export must handle **no-location** gracefully: no
  broken map thumbnail (show *"No location"*), and the frontmatter omits location
  (or records it as null — serializer detail for tech-lead).

### Build dependency (tech-lead)

- Info.plist: `NSLocationWhenInUseUsageDescription` +
  `NSLocationTemporaryUsageDescriptionDictionary` (purpose key for precise). Correct
  handling of `authorizationStatus` and `accuracyAuthorization`; graceful denied +
  reduced-accuracy paths; and the async fix / backfill the capture flow needs.

### Where I expect push-back

- **Product-lead** may see the priming sheet and the reduced-accuracy nudge as extra
  steps/friction. My defense: priming *raises* grant rates and prevents a cold
  system prompt (net less friction over the app's life), and both surfaces are
  one-time and never block capture. If the owner wants it leaner, I'd drop the
  reduced-accuracy nudge before I'd drop the priming sheet.
