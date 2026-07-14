---
name: dont-handwave-hardware
description: Design feedback — never dismiss a device-behavior concern as an acceptable "wrinkle" in docs without validating on hardware; the keyboard-vs-tab-bar trap was a real defect I mislabeled.
metadata:
  type: feedback
---

**Don't hand-wave device-behavior concerns as acceptable "wrinkles" in design docs.
If something depends on how it feels/behaves on real hardware, flag it as a risk to
validate — don't rationalize it away.**

**Why:** I documented that the always-up keyboard covering the iOS 26 floating tab
bar (two-tab model, launch keyboard-up) was "fine, consistent with Messages/Mail,
dismiss to switch tabs." On device it was a **trap** — no obvious way to dismiss the
keyboard to reach Triage. The owner hit it and had to add a stopgap. My comparison to
Messages/Mail was wrong: those don't launch keyboard-up over the primary navigation.
I reasoned from the HIG in the abstract instead of the actual interaction.

**How to apply:**
- When a layout puts a keyboard, sheet, or floating chrome near other persistent
  chrome (tab bar, toolbar, home indicator), treat "does the way *out* stay
  reachable?" as a must-verify, not a footnote.
- If I catch myself writing "this is fine / an honest wrinkle / matches App X,"
  stop and check whether App X actually does *this exact* combination, and whether it
  needs on-device confirmation.
- Owner builds/tests on hardware (walking-skeleton ethos). Surface interaction risks
  as explicit "validate on device" items so they're caught before shipping, not after.
- Treat such a report as a defect to fix at the root, not to defend.

Related: [[nav-model]], [[native-feel-risks]].
