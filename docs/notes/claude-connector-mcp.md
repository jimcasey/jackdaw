# Claude connector (remote MCP) — requirements, auth, hosting, write-safety

Researched 2026-09-26 against current docs. Status tags: **[C]** confirmed in a cited
primary source, **[I]** inferred / not verified end to end. Nothing was deployed or signed up for.

## 1. What a custom connector is and where it works

- One remote MCP server URL added as a **custom connector** at claude.ai
  **Customize > Connectors > Add custom connector**. Works on Free (max 1 custom connector), Pro, Max,
  Team, Enterprise. On Team/Enterprise only an Owner adds it. [C] [add-unlisted], [help-11175166]
- Once connected it is available on **web, desktop and mobile**, and in **Claude Code** (terminal, IDE,
  cloud sessions) when Claude Code is logged in with the claude.ai account (not with an API key). Same
  connector infrastructure backs all surfaces. [C] [getting-started], [cc-mcp §Use MCP servers from claude.ai]
- Setup is done on web or desktop. Mobile *uses* remote connectors; no doc describes adding one
  from mobile. [I]
- **Claude always calls the server from Anthropic's cloud, not the user's device**, on every surface
  including desktop and mobile. The server must be publicly reachable over HTTPS from Anthropic's
  egress range **`160.79.104.0/21`**. So must the OAuth authorization server's discovery and token
  endpoints. [C] [help-11175166], [auth §Network reference, §Serve discovery metadata]
- Claude Code can also add the server itself: `claude mcp add --transport http <name> <url>`. It does its
  own OAuth with a loopback redirect. That connection goes from the dev machine, not Anthropic's cloud.
  A server you add in Claude Code wins over a claude.ai connector with the same URL. [C] [cc-mcp]
- stdio is local only (Claude Code, or Claude Desktop through MCPB extensions). Not relevant for a
  server-side vault except in local dev. [C] [add-unlisted]
- Anthropic's own "MCP tunnels" (outbound-only, no public endpoint) are **Enterprise-only research
  preview**, so not an option for this project. [C] [tunnels]

## 2. Transport

- Use **Streamable HTTP**. Claude still supports legacy HTTP+SSE, but it is deprecated (URL ending in
  `/sse` selects it). [C] [building-index]
- The spec moved on: **MCP 2026-07-28** makes the protocol stateless. It drops `initialize`, drops
  `Mcp-Session-Id`, replaces server-initiated requests (elicitation, sampling) with Multi Round-Trip
  Requests, and deprecates DCR in favour of CIMD. [C] [spec-changelog]
- The auth specs Claude's hosted client lists are 2025-03-26, 2025-06-18 and 2025-11-25.
  [C] [building-index] Claude Code's v2 runtime negotiates 2026-07-28 with HTTP servers that support
  it. [C] [cc-mcp §client runtimes] So hosted Claude is most likely a "legacy" (2025-era) client, and
  the server must serve 2025-era clients. [I]
- Limits on the hosted surfaces: tool result about 150,000 characters, and 240 s per tool call. In
  Claude Code the default limit is 25k tokens (`MAX_MCP_OUTPUT_TOKENS`). [C] [building-index]
- Hosted Claude does **not** support resource subscriptions or sampling. Resources, prompts, text and
  image results are supported. [C] [building-index]

## 3. Auth

### What Claude's client does [C] [auth]
- Supported types: `none` (authless), `oauth_dcr`, `oauth_cimd`, and your own client ID/secret entered
  in Advanced settings. `static_headers` (a fixed API key in a request header) is **beta for a limited
  set of organizations** and is set up by an org Owner. It is probably not available to an individual
  Pro/Max account. [C for beta/limited; I for individual accounts]
- The sign-in flow starts only from a **401** carrying
  `WWW-Authenticate: Bearer resource_metadata="…/.well-known/oauth-protected-resource"`. Claude ignores
  that header on a 200.
- The protected resource metadata `resource` must equal the connector URL exactly. Claude uses **only
  the first** entry in `authorization_servers`.
- PKCE S256 is always used. The server should advertise `code_challenge_methods_supported: ["S256"]`.
  Claude sends the RFC 8707 `resource` parameter.
- CIMD is used only if the AS metadata has `client_id_metadata_document_supported: true` **and**
  `"none"` in `token_endpoint_auth_methods_supported`. Otherwise Claude falls back to DCR.
- Redirect URIs to allow: `https://claude.ai/api/mcp/auth_callback` for all hosted surfaces. For Claude
  Code, allow `http://localhost/callback` and `http://127.0.0.1/callback` on **any port**.
- `/token` must accept form-urlencoded. Return `invalid_grant` for a dead refresh token. Rotate refresh
  tokens (Claude is a public client under DCR or CIMD). Claude refreshes on 401 and also up to 5 min
  before expiry.
- Timeouts: 10 s for discovery, registration and token calls; 30 s for refresh.
- Auth settings can't be edited after a connector is added. Remove it and add it again.

### Spec baseline [C] [spec-auth-2025-06-18], [spec-changelog]
- The MCP server is an OAuth 2.1 resource server. It MUST serve RFC 9728 protected resource metadata,
  MUST validate the token audience (no token passthrough), and MUST NOT accept tokens in the query
  string. The AS MUST serve RFC 8414 metadata. Short-lived access tokens are recommended. Refresh
  tokens for public clients MUST be rotated.

### Options for a single-user server that can WRITE the vault
| Option | Verdict |
|---|---|
| **Authless + secret URL path** | Reject. The URL *is* the credential. It ends up in proxy/CDN/tunnel logs, it has no expiry or rotation short of re-adding the connector, and the spec forbids tokens in the URL. Claude's docs describe "No sign-in" as "anyone with access to the server URL can use the connector". One leak means arbitrary writes to every synced device. |
| **Static bearer header** | Would be fine technically, but it is beta, limited to orgs, and entered by an Owner. Likely not available to this account. [I] Fine for Claude Code only (`--header`). |
| **Cloudflare Tunnel + Access with "Managed OAuth"** | Strongest low-code candidate. Access acts as an OAuth 2.0 AS for a self-hosted app: 401 + `WWW-Authenticate` to non-browser clients, RFC 8414/9728 discovery, DCR with allowlisted redirect URIs (add `https://claude.ai/api/mcp/auth_callback`; toggle "allow localhost/loopback" for Claude Code), opaque short-lived tokens plus refresh, policy re-evaluated on every refresh. The origin receives a signed `Cf-Access-Jwt-Assertion` that it should verify. Access policy = owner's email only. [C] [cf-managed-oauth] **Not confirmed with Claude's client** (resource-match rule, first-AS rule, whether Access serves PRM with the exact `resource`), and the plan tier for Managed OAuth is unconfirmed. [I] |
| **Own minimal AS in the server** | Fully under your control. Implement PRM, AS metadata, `/register` (DCR) or CIMD, `/authorize` (owner login, e.g. passkey or password + TOTP, plus a consent screen), and `/token` with rotation. TS SDK v2 is **resource-server only**. The v1 AS helpers (`mcpAuthRouter`, `ProxyOAuthServerProvider`) are frozen in `@modelcontextprotocol/server-legacy/auth`. [C] [sdk-auth] More code and more security surface. |
| **External IdP with DCR/CIMD** (Auth0, WorkOS, Stytch, etc.) | Works if it meets Claude's rules above. Adds a dependency. Not researched in detail. [I] |

## 4. Hosting (the process must be long-running with a local vault directory)
- Needs: public HTTPS reachable from `160.79.104.0/21`, and no WAF, bot-fight or rate-limit rule that
  blocks Anthropic (common failure: 403/429 at the edge). [C] [troubleshooting] With the TS SDK's
  `createMcpExpressApp`, set `allowedHosts` to the public hostname, or DNS-rebinding protection returns
  403. Don't validate `Origin` too strictly. [C] [testing]
- **Home server + Cloudflare Tunnel**: outbound-only, no open ports. A named tunnel needs a domain on
  Cloudflare. Pairs with Access Managed OAuth above. Zero Trust is free up to 50 users. [C for free
  tier: cf-pricing]
- **Home server + Tailscale Funnel**: public TLS on `*.ts.net`, ports 443/8443/10000 only, bandwidth
  capped, all plans, **no auth in front**. The app must do full OAuth itself. [C] [ts-funnel]
- **Small VPS** (Caddy/nginx for TLS) or **Fly.io** (Machine + volume, auto-stop disabled because
  Headless Sync must stay running): the app must do full OAuth itself, or you add Cloudflare in front.
  Fly details not researched. [I]

## 5. Write-safety features of Claude's client
- **Per-tool permissions** at Customize > Connectors > (connector) > Tool permissions: **Always allow /
  Needs approval / Blocked**, per tool or per group. Blocked tools are removed from what Claude sees on
  every surface, Claude Code included. [C] [getting-started], [cc-mcp §Organization controls]
- At call time the user gets **Allow once / Always allow**. [C] [getting-started]
- **Annotations drive the defaults**: tools with `readOnlyHint: true` can run without per-call
  confirmation, and tools with `destructiveHint: true` **always prompt**. Anthropic asks every tool to
  declare `readOnlyHint` and `destructiveHint`, and a `title`. [C] [review-criteria], [mcp-orientation]
  Spec defaults when a hint is omitted: readOnly=false, destructive=true, idempotent=false,
  openWorld=true. Hints are untrusted by spec. [C] [spec-schema] Whether "always prompt" still applies
  after the user picks "Always allow" is unclear. [I]
- Anthropic's review guidance: **split read from write tools**, and ideally split create / update /
  delete into separate tools. That fits a per-tool approval model. [C] [review-criteria]
- **Claude Code only**: `_meta["anthropic/requiresUserInteraction"]: true` forces a prompt on every call,
  even in auto or bypass modes. [C] [cc-mcp]
- **Elicitation**: supported in Claude Code (form + URL). **Not supported in claude.ai**
  (anthropics/claude-ai-mcp#153, open since 2026-04-06). Don't depend on it for confirmation of
  destructive writes. [C] [cc-mcp], [gh-153] Under 2026-07-28 it becomes an MRTR `input_required`
  result. [C]
- **Resources vs tools**: resources are read-only, app-controlled context. Claude.ai supports reading
  them but not subscriptions. All writes must be tools. Reads could be tools too, so the model can call
  them. [C for support; I for design]

## 6. TypeScript SDK status [C] [npm, sdk-auth, sdk-legacy]
- `@modelcontextprotocol/sdk` **1.30.1** (v1 line). **v2 is split packages at 2.1.0**:
  `@modelcontextprotocol/server`, `/node`, `/express`, `/hono`, `/client`, `/core` (published
  2026-09-23). v2 targets 2026-07-28. `createMcpHandler` is stateless per request. By default it serves
  2025-era "legacy" clients statelessly (`legacy: 'stateless'`); `legacy: 'reject'` would lock out
  those clients, so don't use it.
- v2 auth: `requireBearerAuth({ verifier, resourceMetadataUrl })` answers 401/403 with a correct
  `WWW-Authenticate`. `mcpAuthMetadataRouter` serves PRM. There are per-tool `scopeChallenge` /
  `requireScopes` helpers (useful for `vault:read` vs `vault:write`). No AS in v2.
- Inspector 2.8.0 (`npx @modelcontextprotocol/inspector --cli <url> --transport http --method tools/list`).

## Open questions
1. Does Cloudflare Access Managed OAuth pass Claude's connector flow end to end (exact `resource` in
   PRM, DCR with the claude.ai callback)? Is it on the free Zero Trust plan? Needs a throwaway probe.
2. Can this account (individual Pro/Max) use `static_headers`? The docs say an org Owner sets it up and
   it's limited beta.
3. With `destructiveHint: true`, can the user still choose "Always allow" in claude.ai, or is the prompt
   forced?
4. Which protocol revision does hosted Claude negotiate today? This decides whether elicitation-style
   confirmation could ever work there.

## Sources
- [help-11175166] https://support.claude.com/en/articles/11175166-get-started-with-custom-connectors-using-remote-mcp
- [add-unlisted] https://claude.com/docs/connectors/custom/add-unlisted
- [getting-started] https://claude.com/docs/connectors/getting-started
- [building-index] https://claude.com/docs/connectors/building/index
- [auth] https://claude.com/docs/connectors/building/authentication
- [testing] https://claude.com/docs/connectors/building/testing
- [troubleshooting] https://claude.com/docs/connectors/building/troubleshooting
- [review-criteria] https://claude.com/docs/connectors/building/review-criteria
- [mcp-orientation] https://claude.com/docs/connectors/building/mcp
- [tunnels] https://claude.com/docs/connectors/mcp-tunnels/overview
- [cc-mcp] https://code.claude.com/docs/en/mcp
- [spec-auth-2025-06-18] https://modelcontextprotocol.io/specification/2025-06-18/basic/authorization
- [spec-changelog] https://modelcontextprotocol.io/specification/2026-07-28/changelog
- [spec-schema] https://modelcontextprotocol.io/specification/2025-11-25/schema (ToolAnnotations)
- [sdk-auth] https://ts.sdk.modelcontextprotocol.io/v2/serving/authorization
- [sdk-legacy] https://ts.sdk.modelcontextprotocol.io/v2/serving/legacy-clients
- [gh-153] https://github.com/anthropics/claude-ai-mcp/issues/153
- [cf-managed-oauth] https://developers.cloudflare.com/cloudflare-one/access-controls/applications/http-apps/managed-oauth/
- [cf-pricing] https://www.cloudflare.com/plans/zero-trust-services/
- [ts-funnel] https://tailscale.com/kb/1223/funnel
