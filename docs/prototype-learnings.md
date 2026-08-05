# Learnings from the prototype

**Status: not yet written.** This is a placeholder with the intended structure.
Filling it in is [issue #1](https://github.com/jimcasey/jackdaw/issues/1) — do it
early, since it feeds the scope, tagging, and export decisions.

## What this is for

The spike at `~/Code/jackdaw-spike`
([jimcasey/jackdaw-spike](https://github.com/jimcasey/jackdaw-spike)) reached
TestFlight with capture + SwiftData working, and accumulated 9 ADRs, a set of
design docs, per-slice specs, and three personas' worth of project memory.

None of that was copied into this repo. This doc is where those learnings get
**re-examined against the new scope** — triage cut, capture and export kept,
tagging redesigned — and either promoted or dropped. The point of the restart is
that inherited decisions have to re-earn their place.

## How to fill it in

Work through the spike's artifacts and, for each learning, record:

- **What we learned** — one or two sentences.
- **Where it came from** — the spike ADR/doc/commit, so it can be re-read.
- **Verdict** — one of:
  - **Promote** — still true and still in scope → open an ADR (`/adr`) or write
    it into the right persona's memory, in its own PR.
  - **Drop** — was about triage, batch sorting, or the navigation model built
    around a triage inbox; doesn't survive the cut.
  - **Re-open** — was decided for the old scope and needs a fresh decision now.

Three areas deserve particular care, because they sit right on the seam:

- **Export** is *in* scope, so the spike's export work (Obsidian and Apple Notes
  paths, the destination seam) is the strongest promote candidate in the repo —
  but it was designed to run *after* triage, on notes a user had already sorted
  and classified. Check what it assumed the triage stage had already done.
- **Tagging / classification** is being redesigned. The spike deferred it to
  triage; here it has to happen at or near capture. Spike material on this is
  useful as *evidence about the problem*, not as a design to copy.
- **Navigation** was shaped by triage-as-root. That shape is gone; re-derive it.

Source material to mine, in the spike repo:

- `docs/adr/0001`–`0009` — the ratified architectural decisions. Note 0004 is the
  triage-root navigation model (likely drop) and 0007 covers note types/context
  bundles (touches classification — read it before designing tagging).
- `docs/prd/`, `docs/design/`, `docs/slices/` — scope, flows, and per-slice specs
  (the spike's "slices" are this project's issues). `slice-4-triage` and its
  design flows are the clearest drops.
- `docs/ci/xcode-cloud-setup.md` — the CI/TestFlight runbook (likely a straight
  promote; it's toolchain, not scope).
- `.claude/agent-memory/{product,design,tech}-lead/` — the personas' accumulated
  notes, including iOS gotchas that cost real time.

Promote deliberately, one decision at a time — each **promote** becomes its own
ADR PR or a follow-up issue. A bulk copy would quietly reinstate the old scope.
