# Jackdaw — Accessibility Baseline & HIG Conformance

> **Status:** Draft for owner arbitration. Owned by design-lead. This is the
> cross-cutting baseline every screen must meet, plus the specific "does this feel
> native?" risks I'm watching. Reads with the other three design docs.
>
> **Note for the owner (new to iOS):** on iOS, accessibility is not a bolt-on. If
> you use standard SwiftUI controls and the system type styles, most of this is
> free; the places it *isn't* free are the custom bits, which I've flagged per
> screen. The web instinct is to hand-roll controls and font sizes — on iOS that's
> what *breaks* accessibility. Standard components are the accessible path.

---

## 1. The baseline (applies to every screen)

- **Dynamic Type.** All text uses semantic type styles (`.body`, `.headline`, etc.),
  never hard-coded point sizes. Layouts must **reflow** at the largest accessibility
  sizes — no fixed-height rows that clip, no truncation of primary content. The
  capture and note-editor text views must remain fully usable at accessibility
  sizes.
- **VoiceOver.** Every control has a clear label and, where needed, a hint/trait.
  The critical case is **swipe actions**: they are invisible to VoiceOver unless
  also exposed as **accessibility custom actions**. Triage's Keep/Snooze/Discard
  must be operable entirely without swiping (custom actions + the long-press context
  menu cover this). Status changes (note discarded, "Inbox clear," export
  succeeded/failed) should post VoiceOver announcements — **but Capture autosave is
  silent**: never announce "saved" per keystroke (VoiceOver already echoes typed
  text; a repeating "saved" is spam). Announce once, concisely, on **New note**
  ("Note captured, new note") — the one delimiting event.
- **Contrast.** Text meets WCAG AA (≥4.5:1). **Never encode state by color alone** —
  Keep(green)/Discard(red)/Snooze(amber), and pending/failed status, each carry an
  **icon + label**, not just a hue. This covers color-blind users and grayscale.
- **Touch targets.** All interactive controls ≥ **44×44 pt** (Save, the three triage
  verbs, Retry, Re-grant, Undo).
- **Reduced Motion.** Any note fly-out / list reordering / confirmation animation
  honors `Reduce Motion` — substitute a cross-fade for slides/physics. (This is a
  reason triage is a list, not a physics-y card stack.)
- **Haptics.** Subtle, meaningful haptics only (capture-save, discard confirm),
  respecting system haptic settings — never decorative.
- **Safe areas & the iOS 26 floating tab bar.** Content respects safe-area insets,
  the home indicator, and the **floating Liquid Glass tab bar** (which overlays
  content and can minimize on scroll). Nothing important sits under the tab bar or
  behind the keyboard permanently. Use system keyboard-avoidance.
- **Dark Mode & Increase Contrast.** Use system colors/materials so both are free
  and correct.

---

## 2. Per-screen HIG pattern + the a11y watch-item

| Screen | Native idiom invoked | The thing most likely to go wrong |
|--------|----------------------|-----------------------------------|
| **Capture** | Full-bleed **autosave** editor; keyboard is the chrome (Drafts / new Apple Note); **New note** control in the keyboard toolbar (no Save button). | Coming out as a **web-form textarea + Submit button** (doubly wrong — there is no submit). Watch for a bordered input box or a Save CTA. Editor must scale with Dynamic Type; keyboard-toolbar control must not clip at accessibility sizes. **Do not announce autosave per keystroke** (VoiceOver spam) — see capture-flows §1.2. |
| **Triage inbox** | `List` + leading/trailing **swipe actions** (Mail/Reminders). | Swipe actions unreachable by VoiceOver → **must** mirror as custom actions + context menu. State-by-color-only. Rows that clip at large type. |
| **Triage empty state** | `ContentUnavailableView`-style empty state. | The snoozed-count line accidentally becoming a **tappable list** (archive creep). It's text only. Announce "Inbox clear." |
| **Note editor** | Push (drill-in); system date/time picker; MapKit thumbnail; bottom action bar. | Map thumbnail with no text alternative; broken/empty map when there's no location (show "No location"). Pickers are already accessible — don't replace them with custom ones. |
| **Settings & Status sheet** | Modal **sheet**; grouped `Form`/`List`. | Status rows encoding state by color; Retry/Re-grant under 44pt; the queue list drifting toward a browsable archive (keep it status, capped). |
| **Vault setup sheet** | Explainer → **system document picker** (folder). | Building a **custom file browser** instead of using the system picker. Don't. |
| **Location priming sheet** | Small pre-permission rationale → system prompt. | Blocking the first capture; a cold system prompt with no priming. |
| **Undo banner (triage)** | *Custom* transient view (no iOS system snackbar exists). | The one non-stock component. Must use system materials, respect safe areas, be VoiceOver-announced, and auto-dismiss without trapping focus. |

---

## 3. Native-feel risks I'm actively defending against

The owner is new to iOS; the failure mode is "web-shaped UI in a phone frame." The
specific things I will call out in review:

1. **A boxed textarea + Submit button on Capture.** Wrong. Native is a full-bleed
   editor where the keyboard is the chrome. (Highest-risk screen.)
2. **A custom file browser for vault setup.** Wrong. The system document picker is
   *the* sanctioned way to grant folder access (and it's what mints the
   security-scoped bookmark). Don't rebuild Files.
3. **A physics-y card-stack for triage.** Rejected — reduced-motion + VoiceOver
   liability and reads gimmicky. `List` + swipe is the native triage idiom.
4. **Custom fonts / hard-coded sizes / custom toggles-and-pickers.** Use system type
   styles and system controls; they carry Dynamic Type, VoiceOver, and Dark Mode for
   free. Reinventing them is how web-shaped apps break accessibility.
5. **A settings/tab bar with more than the two real modes,** or an "exported /
   history" view. Both would betray the funnel and (in the tab-bar case) the HIG
   rule that tab bars are for top-level sections, not housekeeping.
6. **Modal permission/setup gates on first launch.** The web onboarding instinct.
   First run must be the capture magic; setup and permission are lazy/in-context.

---

## 4. SF Symbols in use (consistency)

Use SF Symbols throughout (they scale with Dynamic Type and adapt to weight/Dark
Mode). Working set, to keep iconography consistent:

- Keep → `checkmark` (green) · Discard → `trash` (red) · Snooze → `moon.zzz` or
  `clock` (amber)
- Capture save → `arrow.up.circle.fill` (or a `checkmark` on confirm)
- Export status → `arrow.up.circle` / `icloud` family; failed → `exclamationmark`
  variant · re-grant → `folder.badge.questionmark`
- Settings → `gearshape`

(Exact glyphs can shift in visual design; the point is symbol-based, Dynamic-Type-
safe iconography, never bitmap icons.)
