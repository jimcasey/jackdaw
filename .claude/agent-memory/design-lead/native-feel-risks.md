---
name: native-feel-risks
description: Web-shaped-UI failure modes to catch in review — owner is a strong web engineer new to iOS and will reach for web patterns that are wrong on iOS.
metadata:
  type: feedback
---

Owner is a strong full-stack/web engineer, **new to iOS**. My single most valuable
function is catching web-shaped UI early and showing the native alternative.

**Why:** web instincts (boxed inputs, submit buttons, custom controls, front-loaded
onboarding gates, building your own file browser) feel right on the web and are
wrong on iOS — and they're also what breaks Dynamic Type / VoiceOver / Dark Mode.

**How to apply — watch for these in comps/PRs and name the native fix:**
1. **Boxed textarea + Submit button on Capture.** Native = full-bleed editor where
   the keyboard is the chrome (Drafts / new Apple Note). Highest-risk screen.
2. **Custom file browser for vault setup.** Native = system document picker (also
   what mints the security-scoped bookmark). Don't rebuild Files.
3. **Physics-y card-stack for triage.** Native = `List` + swipe actions
   (Mail/Reminders); card stacks are a reduced-motion/VoiceOver liability.
4. **Custom fonts / hard-coded sizes / custom toggles & pickers.** Use system type
   styles + system controls — they carry Dynamic Type, VoiceOver, Dark Mode free.
5. **Extra tabs for settings/history**, or any "exported/history" view — betrays the
   funnel and the HIG rule (tab bars = top-level sections, not housekeeping).
6. **Modal permission/setup gates on first launch.** First run = the capture magic;
   setup + permission are lazy/in-context.

Teach the *reasoning* (owner needs to audit generated Swift), don't just assert.
Related: [[a11y-baseline]], [[nav-model]].
