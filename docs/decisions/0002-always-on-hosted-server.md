# 0002 — Host on a small always-on server, not serverless

**Status:** accepted, 2026-09-26 (provider not yet chosen)

## Context

The owner has no machine that can stay on, so Jackdaw must be hosted. Two
constraints shape where: `ob sync --continuous` is a long-lived process holding a
WebSocket and watching a local filesystem, and the vault plus its git history must
persist on a local disk that both `ob` and Jackdaw use
([obsidian-headless-sync.md](../notes/obsidian-headless-sync.md)). Claude's
connector calls originate from Anthropic's cloud, so the MCP endpoint needs public
HTTPS ([claude-connector-mcp.md](../notes/claude-connector-mcp.md)).

## Decision

Run Jackdaw on **one small always-on host with persistent local storage** — a VPS,
or a container platform with an attached volume and no scale-to-zero. `ob` and the
Jackdaw MCP server run side by side on it, sharing the vault directory.

Pure serverless (per-request functions) is ruled out: no long-running sync process,
no durable local filesystem, and re-syncing the vault per request would be slow and
would multiply exposure to `ob`'s startup-deletion risk.

## Consequences

- Provider choice is still open; it must offer node-local disk (not NFS — `ob`
  relies on filesystem watching) and let us run two processes under a supervisor.
- The vault is **decrypted at rest on a third-party host**, along with the `ob`
  auth token and derived E2E key. Disk encryption, minimal access, and secret
  handling become requirements.
- A VPS has a public IP, but fronting it with Cloudflare Tunnel + Access still
  avoids opening inbound ports and gives us OAuth without writing it — if Access
  works with Claude's connector auth (to be tested).
- We own the host's uptime, patching, and monitoring.
