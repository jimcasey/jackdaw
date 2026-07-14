---
name: nav-model
description: Jackdaw nav model — REVISED to Triage-root + Capture-as-sheet (no tab bar) after the two-tab model shipped a keyboard-vs-tab-bar defect on device. External capture is a proposal.
metadata:
  type: project
---

**REVISED (supersedes the earlier two-tab tab bar).** Status: the in-app change is
recommended outright; external-capture-primary is a proposal pending owner
ratification + tech-lead feasibility.

**Recommended in-app model:** **Triage is the root** (`NavigationStack` list of
un-triaged notes). **Capture is a modal sheet** (own keyboard, own `Done`/drag
dismiss) invoked from a prominent capture button on Triage. Settings/Status stays a
sheet from a gear. Note editor still a **push** within Triage. **No tab bar.**

**Why the change — the defect I own:** the original two-tab model launched keyboard-
up on a Capture *tab*; the always-up keyboard covered the iOS 26 floating tab bar
with no reachable dismiss. I had documented this as an acceptable "wrinkle" — on
hardware it was a trap. Root cause: persistent tab bar + persistent keyboard fighting
for the bottom edge. A sheet fixes it *by construction* (no tab bar underneath;
standard compose-sheet + keyboard; always a `Done`). Also better IA: if capture is a
quick action (esp. external), in-app capture is an *action* (button→sheet), not a
*mode* (tab).

**Launch destination:** (A) Triage-root bare (app = processing surface) if external
capture proves low-friction; (B) Triage-root with Capture sheet auto-presented (safe
transition default). **Recommend B now, move to A after on-device validation.** Not a
hard doc-time commit; could be a setting but I'd rather decide once we've felt it.

**External capture (proposed):** one shared App Intent surfaced on Action button /
Siri / Control Center / Lock Screen. See [[external-capture]].

**Where I pushed back:** don't make external capture *primary* until (1) on-device
friction is validated and (2) tech-lead confirms an external intent can get a precise
GPS fix — else external captures degrade to timestamp-only, gutting the ambient-
context promise.

Full doc: `docs/design/navigation-and-screen-inventory.md` §2. Related:
[[funnel-nav-constraint]], [[capture-model]], [[external-capture]],
[[native-feel-risks]].
