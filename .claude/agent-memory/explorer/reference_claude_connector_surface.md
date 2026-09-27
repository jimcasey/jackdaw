---
name: claude-connector-surface
description: Mapped Claude custom-connector (remote MCP) constraints as of 2026-09-26 — reachability, auth rules, write-safety features, SDK v2 status; full note in docs/notes/claude-connector-mcp.md
metadata:
  type: reference
---

Mapped 2026-09-26. Full cited note: docs/notes/claude-connector-mcp.md. Re-verify before relying on it, because these surfaces change monthly.

Load-bearing facts:
- Hosted Claude (web, desktop, mobile) calls the server from Anthropic's cloud (160.79.104.0/21), so the server needs public HTTPS. Claude Code inherits claude.ai connectors or can add the server directly with a loopback OAuth flow.
- Auth: none, OAuth (DCR or CIMD), or your own client ID. static_headers is limited beta for orgs only. Callback URL is https://claude.ai/api/mcp/auth_callback. Sign-in needs a 401 carrying resource_metadata. Claude uses only the first authorization_servers entry.
- Write safety: per-tool Always allow / Needs approval / Blocked. readOnlyHint → no prompt; destructiveHint → always prompts. Elicitation is NOT in claude.ai (GitHub issue anthropics/claude-ai-mcp#153), only in Claude Code.
- MCP spec 2026-07-28 is stateless and deprecates DCR. TS SDK v2 (@modelcontextprotocol/server 2.x) is resource-server only; the authorization-server helpers are frozen in server-legacy.
- Leading low-code auth candidate: Cloudflare Tunnel + Access "Managed OAuth". It has not been verified against Claude's client.

Related: [[obsidian-headless-sync]]
