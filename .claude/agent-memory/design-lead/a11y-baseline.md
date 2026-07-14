---
name: a11y-baseline
description: Accessibility baseline for every Jackdaw screen — Dynamic Type, VoiceOver custom actions for swipe, no color-only state, 44pt targets, reduced motion.
metadata:
  type: project
---

Non-negotiable accessibility baseline for every screen (details:
`docs/design/accessibility-and-hig.md`):

- **Dynamic Type** via semantic styles (never hard-coded sizes); layouts reflow at
  accessibility sizes (capture/editor text views stay usable; rows don't clip).
- **VoiceOver:** all controls labeled; **swipe actions MUST be mirrored as
  accessibility custom actions + a long-press context menu** (swipe actions are
  invisible to VoiceOver otherwise). Triage Keep/Snooze/Discard fully operable
  without swiping. Announce state changes (discarded, "Inbox clear", export result).
  **Capture autosave is silent** — never announce "saved" per keystroke (VoiceOver
  spam); announce once on "New note" only. See [[capture-model]].
- **Contrast** WCAG AA (≥4.5:1); **never encode state by color alone** —
  Keep/Discard/Snooze and pending/failed each carry icon + label.
- **Touch targets** ≥ 44×44 pt (Save, three verbs, Retry, Re-grant, Undo).
- **Reduced Motion:** fly-out/reorder/confirm animations cross-fade (a reason triage
  is a `List`, not a physics card stack).
- **Safe areas / iOS 26 floating Liquid Glass tab bar** (overlays content, minimizes
  on scroll): nothing important sits under it or permanently behind the keyboard.
- System colors/materials → Dark Mode + Increase Contrast free.

**How to apply:** on iOS, standard SwiftUI controls + system type styles are the
accessible path; custom-rolled controls/fonts are where it breaks. Owner is new to
iOS — flag custom bits explicitly in review. Related: [[native-feel-risks]].
