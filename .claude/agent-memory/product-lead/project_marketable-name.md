---
name: project_marketable-name
description: The marketable/App Store name is still TBD — deferred, not decided; pick it up when branding work is warranted
metadata:
  type: project
---

**Status: OPEN — deferred, do not treat as settled.** The marketable name is
explicitly TBD (CLAUDE.md: "marketable name TBD later in the project"). This note
records where it stands so it gets picked up deliberately, not by accident.

**What happened (2026-07-19):** During Xcode Cloud setup the owner hit that
**"Jackdaw" is already taken as an App Store app name.** As an unblocking
placeholder they registered the App Store display name as **"JackdawNotes"** — a
working name, not a chosen brand. The owner asked to defer real naming rather than
run a product-lead naming pass right then.

**Key facts (so we don't over-panic later):**
- The three identifiers are decoupled: **App Store display name** (globally
  unique, user-facing, currently `JackdawNotes`, **changeable** while unreleased)
  ≠ **bundle ID** (`com.jimcodes.Jackdaw`, fixed, fine to keep) ≠ **Xcode
  project/scheme/codename** (`Jackdaw`, internal, keep). Renaming the store
  listing later touches none of the code.
- "Jackdaw" survives as the **internal codename** regardless (per the corvid/crow
  naming convention in CLAUDE.md).

**When to pick this up:** when branding/marketing actually matters — near a public
release, not before. It doesn't block v1 build. It's a **product-lead** call
(product identity/positioning) with **design-lead** on brand feel.

**How to run it when the time comes:** shortlist scored against the
funnel-not-archive positioning (fast on-ramp, notes leave the app — see
[[project_funnel-principle]]); each finalist needs an **App Store name
availability** check + a **trademark** sanity-check. Starter directions floated
2026-07-19 (flavor only, unchecked): fleeting-capture (Wisp, Flit, Ember, Jot,
Nib); funnel metaphor (Sluice, Chute, Passage, Throughline); quick-note (Inkling,
Margin, Scratch, Aside); corvid-adjacent (Rook, Corvid, Clatter). Record the final
choice as an ADR or in the PRD when made.
