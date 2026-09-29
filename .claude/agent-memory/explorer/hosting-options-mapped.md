---
name: hosting-options-mapped
description: Hosting providers compared 2026-09-26 for the always-on ob+MCP host — shortlist, key price/encryption facts, gotchas; full note docs/notes/hosting-options.md
metadata:
  type: reference
---

Mapped 2026-09-26. Full cited note: docs/notes/hosting-options.md. Prices move a lot (Hetzner raised prices 4x in 2026, and Fly changed its prices on 2026-10-01), so re-check them before quoting.

Shortlist: 1) Fly.io (shared-cpu-1x 1GB plus volume, about $8/mo), 2) Hetzner CX23 (about €7, EU only), 3) Linode Nanode ($7, local disk encrypted by default).

Load-bearing facts:
- Fly volumes are a local NVMe slice, encrypted by default, with daily snapshots (first 10GB free). `fly deploy` may create a new empty volume. Any volume with the same name may be mounted.
- Local disks are NOT encrypted on DO (per its own shared-responsibility page), Hetzner (no offering) or Vultr. Linode encrypts local disk by default, but its backups are unencrypted.
- Ruled out:
  - Cloudflare Containers: ephemeral disk.
  - Durable Objects: no POSIX filesystem.
  - Render: no 1GB tier, so $25 minimum.
  - Railway Hobby: 5GB volume cap.
  - Oracle free: reclaims idle instances.
  - GCP free: 1GB egress limit.
- Attached block volumes work fine with inotify, but a failed mount leaves an empty mountpoint. The sentinel guard is therefore required on every provider.

Owner decision still pending (as of 2026-09-26): managed container vs self-patched VPS, and whether EU hosting is OK.

Related: [[headless-sync-mapped]], [[claude-connector-surface]]
