# ADR 0009 — Media (now-playing) context: sources, routes, and the verified no-launch read

> **Status:** Accepted — records the capture-wave plan's §8.2
> (`docs/prd/capture-wave.md`, PR #28) with the **S1 spike results**
> (issue #29; probe shipped in PR #37/#39, reverted after confirmation).
> **Refines ADR 0008:** the "external context = caller-supplied parameters,
> never background reads" principle gains one verified exception — the
> no-launch Apple-Music read — used as best-effort enrichment only.
> **Date:** 2026-07-23
> **Owner of decision:** tech-lead, arbitrated by owner.

## Context

The Listening type (ADR 0007) wants "what I'm listening to" attached
automatically. The feasibility matrix (research:
`.claude/agent-memory/tech-lead/now-playing-and-v1x-wave.md`, summarized in
the plan §3): Apple Music is readable via MediaPlayer/MusicKit behind a
media-library permission; **Apple Podcasts exposes no API at all**;
system-wide now-playing (`MPNowPlayingInfoCenter`) is publish-only;
MediaRemote is private. Owner inputs (plan §7.5): **Apple Podcasts user, not
a Spotify user.**

The one open question the plan deferred to a spike: does the Apple-Music
read work from a **no-launch App Intent** (app backgrounded or terminated),
or foreground-only? Prior forum reports suggested background reads were
flaky-to-dead.

### S1 spike results (owner's device, iOS 26.x, 2026-07-23)

Probe read both public routes with a song playing in Apple Music:

| Case | Result |
|------|--------|
| Foreground (in-app) | **YES** — `MP item: Also Frightened — Animal Collective`; MusicKit agreed |
| No-launch intent, app backgrounded (warm) | **YES** — identical read |
| No-launch intent, app **force-quit** (cold) | **YES** — identical read |

Both `MPMusicPlayerController.systemMusicPlayer` and MusicKit
`SystemMusicPlayer` returned the current item in all three cases, with
authorization statuses readable throughout. Better than the plan's
"assume NO until spiked" posture.

**Caveat kept deliberately:** one device, one OS version, one session-state;
public reports of background flakiness exist. The result upgrades the
no-launch read from "assumed dead" to **"verified, treat as best-effort"** —
not to "guaranteed".

## Decision

1. **Apple Music is the sole live media auto-context source.**
   - **In-app (slice C):** a `NowPlayingProviding` protocol mirroring
     `LocationProviding` (one-shot async snapshot, plain value type;
     MediaPlayer/MusicKit imports confined to the concrete implementation).
     Foreground read, verified.
   - **No-launch (Listening-typed external captures):** the intent MAY
     attempt the same direct read in `perform()` — verified working warm and
     cold — as **best-effort enrichment**. A nil read commits the note
     without media context, silently (the affinity model, ADR 0007, absorbs
     absence by design).
2. **Precedence when both routes could apply:** explicitly **piped
   parameters win over the direct read** — a Shortcut that supplies media
   parameters (slice D) is expressing intent about *which* media the note is
   about; the direct read fills in only when nothing was supplied. Piped
   parameters remain the contract-guaranteed route (ADR 0008's principle);
   the direct read is opportunistic.
3. **Podcasts:** Apple Podcasts is **dead for pull** (no API, no
   current-episode Shortcuts action — structural, not behavioral, so no
   spike needed). The **share route** (ADR 0008) is the podcast path:
   episode URL into the media parameters. Revisit trigger: the owner
   switches to a podcast app that exposes a current-episode action.
4. **Rejected outright:** MediaRemote (private framework — breaks silently
   across iOS releases; not acceptable even under TestFlight-internal review
   tolerance) and the Spotify Web API (owner is not a Spotify user; would
   add OAuth + the app's first network dependency for nothing).
5. **Permission UX:** `NSAppleMusicUsageDescription` +
   media-library/MusicKit authorization, primed **lazily and in-context on
   the first Listening-relevant capture** — never front-loaded (design
   requirement, plan slice C).
6. **String constraint (learned the hard way, ITMS-90626):** App
   Intents-visible strings — intent titles, descriptions, App Shortcut
   phrases — **must not contain "apple"**; App Store Connect rejects the
   upload at delivery validation. Say "system music player" / "current
   song". Info.plist permission strings are unaffected. (Runbook gotcha:
   `docs/ci/xcode-cloud-setup.md`.)

## Consequences

**Positive**
- The Listening type gets real auto-context on **every** surface class for
  the song case: foreground reads in-app and on launcher surfaces, the
  direct best-effort read on no-launch captures, piped parameters when a
  Shortcut supplies them.
- No new dependencies, no network, no private API.

**Negative / accepted**
- The no-launch direct read is best-effort on a single-device verification;
  if an OS update kills it, notes silently degrade to media-less — exactly
  the failure mode the affinity model already absorbs. No contract depends
  on it.
- Podcast context arrives only via the deliberate share gesture; a podcast
  thought captured through the plain speed lane carries no episode metadata.
  Accepted — the type still labels it, and triage can add context.
- A second permission prompt (media library) joins location. One-time,
  owner-only, lazily primed.

## Related

- `docs/prd/capture-wave.md` §3, §7.5, §8.2 — the ratified plan this records.
- ADR 0007 (Listening type + media frontmatter keys) · ADR 0008 (surface
  lanes; the parameter principle this refines; the share route).
- Issue #29 (spike, closed by this ADR's PR) · PRs #37/#39 (probe) — probe
  code reverted in the same PR as this ADR; the
  `NSAppleMusicUsageDescription` key is retained (inert until slice C).
- Research + spike record:
  `.claude/agent-memory/tech-lead/now-playing-and-v1x-wave.md`.
