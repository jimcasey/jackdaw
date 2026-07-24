---
name: location-permission
description: Location permission UX — When-In-Use precise, in-context priming sheet, never blocks first capture; graceful denied + reduced-accuracy fallbacks.
metadata:
  type: project
---

Owner chose **precise (GPS)**, not coarse. Permission UX:

- **When-In-Use, precise — NOT Always** (capture is foreground only; Always is a
  heavier/creepier ask with no v1 benefit). Insist on this.
- **Ask in context, primed, never at first launch.** First capture is never
  interrupted: text field is live immediately; a lightweight **location priming
  sheet** appears when the owner saves their first note (or a beat after the screen
  settles), then triggers the system prompt. Cold system prompts are a mistake.
- **Denied fallback:** capture works fully with **timestamp only**, no location, and
  **no per-capture nag**. Surface denied once, calmly, in Settings + deep-link.
- **Reduced-accuracy wrinkle (iOS 14+):** user may grant location with Precise OFF
  (`accuracyAuthorization == .reducedAccuracy`). One-time gentle nudge offering
  `requestTemporaryFullAccuracy(purposeKey:)` or Settings deep-link. Don't nag.
- Editor + serializer must handle **no-location** gracefully (show "No location", no
  broken map thumbnail; frontmatter omits/nulls location).

**Build seam (tech-lead):** Info.plist `NSLocationWhenInUseUsageDescription` +
`NSLocationTemporaryUsageDescriptionDictionary` (purpose key); handle
authorizationStatus + accuracyAuthorization; **capture must persist a note before a
GPS fix exists and backfill** the coordinate async (note can briefly be
`location: pending`).

**Push-back expected:** product-lead may call priming/nudge friction — both are
one-time and never block capture; would drop reduced-accuracy nudge before priming.

**Priming trigger vs. external capture (ruled in PR #41 review):** priming fires
only on Capture-*sheet* dismiss — correct **by construction** today: only sheet
captures can carry location (no-launch intents are timestamp-only per ADR 0005),
and slice E deep-links open the sheet, so every location-capable path passes the
trigger. **Known gap deferred to slice F:** the last-known-location cache needs
authorization to ever exist; if external capture dominates and the owner rarely
opens the sheet, location stays un-primed and the cache stays empty. Revisit the
trigger (e.g., prime on a Triage visit after N external captures) as part of
slice F's design — not before.

Full doc: `docs/design/open-ux-threads.md` (Thread 5).
