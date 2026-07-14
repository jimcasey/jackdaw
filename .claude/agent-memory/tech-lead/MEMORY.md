# Memory Index

- [Obsidian write mechanism decision](decision-obsidian-write.md) — ADR 0001: folder-write via security-scoped bookmark; git-push is the fallback.
- [iOS platform gotchas](ios-gotchas.md) — Verified sandbox/URL-scheme/bookmark facts to avoid re-deriving or misciting.
- [Walking-skeleton build order](build-order.md) — Ratified slice sequence in docs/build-order.md; lazy vault setup, two-tab nav, Talon seam contracts, open owner calls.
- [Stack ADRs 0002/0003](stack-recommendations.md) — Ratified: min iOS target = iOS 26 (ADR 0002), persistence = SwiftData (ADR 0003); load-bearing at Slice 0 / Slice 2.
- [Slice 1 spec](slice-1-spec.md) — Vault bookmark write+verify harness in docs/slices/; Talon seam seed, UserDefaults storage, no-iOS-entitlement fact, T2/T1 PASS/FAIL protocol. PASSED on-device; T2 ratified.
- [Slice 2 spec](slice-2-spec.md) — Thin capture + SwiftData in docs/slices/; Note model shape, MVVM↔SwiftData (reads-in-view/writes-in-VM), tab-shell-now, additive-migration stance.
