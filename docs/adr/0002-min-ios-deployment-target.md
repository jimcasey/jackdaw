# ADR 0002 — Minimum iOS deployment target = iOS 26

> **Status:** Accepted — minimum deployment target is **iOS 26**.
> **Date:** 2026-07-14
> **Owner of decision:** tech-lead, arbitrated and ratified by owner.
> **Load-bearing at:** Slice 0 (walking skeleton) — the deployment target must be
> set at Xcode project creation and gates every API available thereafter.
> See `docs/build-order.md`.

## Context

The **deployment target** on iOS is the *oldest* OS version the app will run on.
It is a genuine, up-front architectural choice because it gates the entire API
surface: a *lower* target reaches more devices but forces newer APIs behind
`@available` checks with hand-written fallbacks; a *higher* target lets us call
modern APIs freely with no availability ceremony.

CLAUDE.md marks the min iOS target as TBD and requires it be ratified via ADR
before we rely on it. It becomes load-bearing at the very first slice: you must
choose a target the moment the Xcode project is created.

Facts relevant to the choice (verified 2026-07-14):
- As of 2026-07 the current major iOS is **26.x**. Apple renumbered from iOS 18
  straight to **iOS 26** at WWDC 2025 to align OS names with the release year;
  iOS 27 is due fall 2026.
  ([Apple security releases](https://support.apple.com/en-us/100100),
  [iOS 26 — Wikipedia](https://en.wikipedia.org/wiki/IOS_26))
- **Jackdaw is a single-user app running on the owner's own iPhone.** There is no
  install base to support — the usual reason to lower the target (reach older
  devices) does not apply.
- SwiftData (the persistence choice, ADR 0003) **requires iOS 17 or later** as a
  floor. Whatever target we pick must clear that floor.
  ([SwiftLee — minimum iOS version](https://www.avanderlee.com/workflow/minimum-ios-version/))

## Decision

**Set the minimum deployment target to iOS 26** (the current major), falling back
to iOS 18 only if some tool in the build chain lags.

Rationale, in priority order:
1. **No install base to serve.** Single user, single device — the only device
   that must run Jackdaw is the owner's phone, which runs the current OS. The
   trade that normally argues *for* a low target (device reach) is absent.
2. **Cleanest API surface.** A high target means we call modern SwiftUI,
   SwiftData, and Foundation APIs directly, with no `@available` branching and no
   fallback code to maintain. For an owner still building Swift reading speed,
   fewer availability-gated code paths is materially easier to audit.
3. **Clears the SwiftData floor with room to spare.** ADR 0003 chooses SwiftData,
   which floors the target at iOS 17; iOS 26 satisfies that and gives SwiftData at
   its most mature.

## Consequences

**Positive**
- Zero availability ceremony: modern APIs are called directly.
- SwiftData (ADR 0003) is available and mature; no weak-linking workarounds.
- Simpler code for the owner to read and audit.

**Negative / accepted**
- The app will not install on devices older than iOS 26. **Accepted** — there are
  none in scope (single user, current device).
- Raising a target later is cheap and non-breaking; *lowering* it later would be
  costly (it would strand APIs we relied on). We are choosing the easy-to-relax
  direction deliberately. If the app ever needed a broader install base, this ADR
  would be revisited — not a v1 concern.

## Related
- ADR 0003 (persistence = SwiftData) — depends on this target clearing its iOS 17
  floor.
- Build order: `docs/build-order.md` (load-bearing at Slice 0).
- CLAUDE.md stack defaults (min iOS target was TBD; this ratifies it).
