---
name: nav-model
description: Jackdaw v1 navigation model — two-tab tab bar (Capture | Triage), launch-to-Capture, settings/status as a sheet not a tab.
metadata:
  type: project
---

Jackdaw v1 navigation is a **two-tab `TabView`: `Capture` and `Triage`**. Settings
/ vault status / export status is a **sheet** reached from a gear in the Triage nav
bar — NOT a third tab.

**Why:** HIG says tab bars are for top-level *sections/modes*, not actions or
settings (iOS 26 reiterated this with Liquid Glass tab bars). Jackdaw has exactly
two co-equal modes used at different times — capture (in the wild) and triage
(sit-down). Housekeeping is a subtask → sheet.

**How to apply:**
- App **always launches to Capture with the keyboard up** — never restore last tab
  (restoring could open onto the pile, fighting the funnel + friction mandate).
- Note editor is a **push** within the Triage nav stack (drill-in), with the three
  triage verbs in a bottom bar. Vault setup / location priming are **sheets**.
- Alternative considered & rejected: Capture-as-root with Triage pushed (more
  funnel-pure, less discoverable). Can revisit if owner wants max funnel purity
  over convention.
- Keyboard covers the floating tab bar at launch — intentional, matches
  Messages/Mail; dismiss keyboard to switch tabs.

Full doc: `docs/design/navigation-and-screen-inventory.md`. Related:
[[funnel-nav-constraint]].
