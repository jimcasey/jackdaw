# Hosting options for the always-on host

Researched 2026-09-26. All prices and docs below were checked on that date. This
note serves [decision 0002](../decisions/0002-always-on-hosted-server.md), which
fixes the constraints: one always-on host, `ob sync --continuous`, the Jackdaw MCP
server and git under a supervisor, a shared vault directory on node-local disk,
and public HTTPS reachable from Anthropic (`160.79.104.0/21`).

Legend: **[C]** means confirmed from the cited official page. **[C2]** means from
a secondary source only, because the official page was unreachable (JS-rendered
or 403). **[I]** means inferred.

## Sizing assumptions

These are stated assumptions, not measurements.

- **Vault:** 100 MB–2 GB.
- **Disk:** git history for a 2 GB vault (git dir outside the vault) roughly
  doubles that. Add `ob`'s `state.db`, Node, the image or OS, and headroom, and
  plan on **≥10 GB**. 20 GB is comfortable. [I]
- **RAM:** two Node 22 processes plus `cloudflared` (~30–50 MB), plus git
  spikes. `git gc` or repacking a multi-GB repo can take hundreds of MB. **1 GB is
  the practical floor, 2 GB is comfortable, and 512 MB is too tight.** [I]
  Nobody has measured `ob`'s real memory use on the owner's vault yet; that is
  open question #9 in [obsidian-headless-sync.md](obsidian-headless-sync.md).
- **Traffic:** low. The initial vault download is ingress, which is free
  everywhere. Egress is sync uploads plus MCP responses, likely a few GB a month
  at most. [I]

## The cross-cutting risk: an empty or unmounted vault at startup

`ob` deletes on the remote any file it knows about that is missing on disk at
startup. So the question for each provider is whether a restart or redeploy can
start the processes against an empty directory.

- **VPS, vault on the root disk:** the directory can't be "unmounted". This is
  the safest shape. [I]
- **VPS, vault on an attached block volume** (DO Volumes, Hetzner Volumes,
  Lightsail disks):
  - If the fstab mount fails, the mountpoint is an empty directory. This is the
    classic foot-gun.
  - Mitigate with systemd `RequiresMountsFor=` plus the sentinel-file guard. [I]
  - Network *block* devices are fine for inotify, because the kernel sees a local
    ext4/xfs filesystem. Only network *file* systems (NFS/SMB/FUSE) are a
    problem. [I]
- **Fly.io:**
  - `fly launch` and `fly deploy` will **create a new volume if they "need to"**
    (`initial_size`).
  - "Any volume with this name, in the same region… may be mounted". A stray
    second volume with the same name (a restore, a fresh one) could therefore get
    attached. [C] [fly-config]
- **Render and Railway:** the disk mounts at runtime, and anything written to the
  mount path at build time is lost. [C] for Railway's single-volume limits
  [railway-vol]. [I] for the build-time detail.

Every option therefore needs the **sentinel-file startup guard** already in the
architecture proposal. It is not optional anywhere.

## Comparison

Monthly USD prices. "Smallest viable" means ≥1 GB RAM.

| Provider | Smallest viable plan | ~$/mo incl. backups | Disk (node-local?) | Encryption at rest (provider) | Backups / snapshots | Ops burden | Regions | Notes |
|---|---|---|---|---|---|---|---|---|
| **Hetzner Cloud** CX23 | 2 vCPU / **4 GB** / 40 GB NVMe | €5.49 + €0.50 IPv4 + 20% backups ≈ **€7.1 (~$8.4)** [C] | Local NVMe root [C] | **Not offered** for Cloud servers. DIY LUKS [I] | Daily, 7 slots, 20% [C][C2]. Snapshots €0.0143/GB [C2] | Self-patch VPS | CX/CAX **EU only** (DE/FI). US needs CPX11 at **$20.49** [C] | Best RAM per $. Four price rises in 2026 |
| **DigitalOcean** Basic | 1 vCPU / 1 GB / 25 GB | $6 + 20% weekly or 30% daily ≈ **$7.2–7.8** [C] | Local hypervisor disk | **Local disk NOT encrypted** [C]. Volumes are (LUKS) [C2] | % plans, or usage-based from $0.01/GiB. Snapshots $0.06/GB [C] | Self-patch | Many (US/EU/APAC) | IPv4 is a $0.00 line item "subject to change" [C] |
| **Akamai / Linode** Nanode | 1 vCPU / 1 GB / 25 GB | $5 + $2 backups = **$7** [C]. 2 GB plan $12 + $2.50 | Local | **On by default** (core regions), platform-managed keys. **Backups NOT encrypted** [C] | Managed backups [C] | Self-patch | Many | Only VPS with default local-disk encryption |
| **Vultr** Regular | 1 vCPU / 1 GB / 25 GB | $5 + 20% = **$6** [C2] | Local SSD | Local disk not encrypted. Block Storage is AES-256 [C2] | Auto-backups +20%. Snapshots $0.05/GB [C2] | Self-patch | Many | Pricing page returned 403, so figures are secondary |
| **AWS Lightsail** | 1 GB bundle (2 vCPU burst) / 40 GB† | $7 + snapshots $0.05/GB-mo ≈ **$7.5–8** [C] | System disk; attached disks are network block | Attached disks and snapshots **encrypted by default** [C]. System disk **unconfirmed** | Auto and manual snapshots $0.05/GB [C] | Self-patch | Many | AWS says use the system disk "only for temporary data" [C] |
| **Oracle Cloud** Always Free | A1 up to 2 OCPU / 12 GB, or E2.1.Micro 1 GB [C] | **$0** | Block/boot volume (network block) | **Encrypted by default** (AES-256, CMK optional) [C2 of OCI docs] | 5 volume backups free [C] | Self-patch | Home region only [C] | **Idle reclaim** (see notes). A1 capacity often unavailable [C] |
| **GCP** e2-micro free | 2 shared vCPU / 1 GB [I] | **$0**, plus a possible IPv4 fee | 30 GB standard PD (network block) [C] | Google-managed by default [I, not re-fetched] | Snapshots not in free tier [I] | Self-patch | us-west1/central1/east1 only [C] | **Only 1 GB/mo free egress** [C] |
| **Fly.io** Machine + volume | shared-cpu-1x / 1 GB | ~$5.69 now, **~$6.69 from 2026-10-01**, + $0.15/GB volume (10 GB = $1.50) ≈ **$7.2–8.2** [C] | **Local NVMe slice on the same host** [C] | **Encrypted by default** [C] | Daily block snapshots, 5-day default (1–60). $0.08/GB, **first 10 GB free** [C] | Managed runtime. You rebuild the image to patch | Many | Volume pinned to one host, no replication [C]. Tunnel optional |
| **Railway** Hobby/Pro | usage: $10/GB-RAM, $20/vCPU-mo [C] | ~$10–15 on Hobby ($5 incl. credit); **Pro $20 min** if the volume is >5 GB [C] | Volume, 3k IOPS [C] | "Encrypted at the storage level", per staff forum post 2024 [C2] | Daily/weekly/monthly backups, incremental [C] | Managed | Several | **Hobby volume cap 5 GB** [C]. Tight for a 2 GB vault plus git |
| **Render** | Starter 512 MB $7 is too small. Next tier is **Standard 2 GB at $25** [C] | **~$27.5** (+ disk $0.25/GB) [C] | Local SSD disk [C] | **Encrypted, including snapshots** [C] | Daily snapshots, kept ≥7 days [C] | Managed | Several | No 1 GB tier. Hobby includes only 5 GB bandwidth, then $0.15/GB [C] |
| **Cloudflare Containers / Durable Objects** | — | — | Containers: **ephemeral disk**, `sleepAfter` defaults to 10 min [C]. DO: SQLite/KV API, **no POSIX FS** [C] | — | — | — | — | **Ruled out.** Confirmed they can't host `ob` with persistent local disk |

† The 40 GB system disk is from AWS's general bundle table and was not
re-checked. The $5 bundle is only 0.5 GB RAM.

## Per-provider notes

**Hetzner.**
- Cheapest by far per GB of RAM. The CX23's 4 GB removes all memory worry,
  including git repacks.
- Prices changed on 2026-06-15: CX23 went from €3.99 to €5.49, and CAX11 from
  €4.49 to €5.99. Existing servers keep their old price, but a rescale reprices.
  [C] [hz-price]
- The cost-optimized CX/CAX lines are EU-only. In the US the cheapest option is
  CPX11 at $20.49, which kills the price advantage. [C]
- Anthropic → EU adds roughly 100 ms of RTT, which is irrelevant for MCP. [I]
- Hetzner says nothing about encryption at rest for Cloud servers; treat it as
  none. [I] You could put the vault on a LUKS file or partition, but the key has
  to be on the host for unattended reboot, so the gain is limited to "a stolen
  drive or a decommissioned disk". [I]
- Backups are daily with 7 slots, and they do **not** include attached Volumes.
  [C] [hz-backup]

**DigitalOcean.**
- Their own shared-responsibility page says: "The virtual disks for Droplets
  stored on the hypervisor's local storage are not encrypted at rest." [C]
  [do-srm]
- To get provider encryption you'd put the vault on a Volume (+$1/10 GB [I]).
  That brings back the mount-failure foot-gun.
- Nothing else is distinctive about it for this project.

**Akamai/Linode.**
- The Nanode 1 GB is $5 and backups are $2. [C] [linode-na]
- Local disk encryption is **on by default** in core regions, with keys managed
  by the platform. [C] [linode-enc]
- Caveat: "Backups are not encrypted even when they are taken from an encrypted
  disk." [C] So if you enable backups, a decrypted vault copy sits unencrypted in
  their backup store. That may still be acceptable, but it is a real tradeoff.
- 1 GB is at the floor. The 2 GB plan is $12. [C]

**Vultr.**
- Comparable to DO at $5 for 1 GB. [C2]
- The official pricing and product pages returned 403 to the fetcher, so the
  figures come from secondary sources.
- No provider encryption on local disk. [C2]
- There is no reason to pick it over Linode for this workload. [I]

**AWS Lightsail.**
- $7 for 1 GB. [C] [ls-price]
- Attached disks and snapshots are encrypted by default. [C] [ls-bs] Whether the
  system disk is encrypted is not stated in the official FAQ; only community
  re:Post threads cover it (unfetched).
- To be certain of encryption you'd put the vault on an attached disk, which is a
  network block device. That brings back the unmounted-mountpoint risk.
- AWS itself recommends using the system disk "only for temporary data". [C]

**Oracle Always Free.**
- Generous (A1 up to 2 OCPU / 12 GB) and $0. [C] [oci-free]
- Volumes are encrypted by default. [C2]
- **The idle-reclaim rule is exactly our profile.** An instance is reclaimed if,
  over 7 days, p95 CPU < 20%, network < 20%, and, on A1 only, memory < 20%. [C]
  An idle sync peer will usually meet this.
  - Upgrading the tenancy to Pay-As-You-Go appears to exempt it, since the policy
    names only "Always Free compute instances". [C/I]
  - Reclamation of a host holding the only local copy is survivable, because the
    vault lives in Sync. But it is disruptive, and it's a startup-guard test we
    don't want to run involuntarily.
- A1 capacity is frequently "out of host capacity". [C]
- Fine as a $0 experiment host. Not recommended as the primary.

**GCP e2-micro.**
- One free instance in 3 US regions, with a 30 GB standard PD. [C] [gcp-free]
- **Only 1 GB of free egress a month** (excluding China and Australia). [C]
  Sync uploads plus MCP responses could exceed that; overage is cheap but not
  zero. [I]
- Whether the free tier covers the external IPv4 is unclear. You can avoid needing
  one by running a Tunnel, which needs only outbound traffic, but the VM still
  needs internet egress. [I]
- 1 GB of RAM is at the floor.

**Fly.io.**
- **What you get:**
  - A volume is "a slice of an NVMe drive on the same physical server as the
    Machine". [C] [fly-vol] It is truly node-local, so inotify works.
  - Volumes are encrypted at rest by default. [C]
  - Daily snapshots are on by default, with 5-day retention configurable from 1
    to 60 days. They are billed on stored size at $0.08/GB after the first free
    10 GB. [C] [fly-price]
  - Secrets go through `fly secrets` as env vars, which suits `OBSIDIAN_AUTH_TOKEN`.
    [I, standard Fly feature, not re-fetched]
- **Pricing:** the shared-cpu-1x 256 MB base is $1.94, plus $5/GB of RAM, so
  1 GB ≈ $5.69. [C] [fly-pricing-page] **From 2026-10-01** the base is $2.19 and
  RAM is $6/GB, so 1 GB ≈ $6.69 and 2 GB ≈ $12.69. [C] [fly-update]
- **Gotchas:**
  - The volume lives on one host with no replication. If the host fails, the
    Machine is down until you restore a snapshot to a new volume. Fly tells you to
    run ≥2 volumes. [C] We can't, because two `ob` peers on one vault would be
    wrong. The vault itself lives in Sync, so this costs downtime, not data. [I]
  - Deploy can auto-create an empty volume (see the cross-cutting section). [C]
  - A Machine with no `[http_service]` gets no public ingress, so a Tunnel-only
    setup has zero public surface. Otherwise `*.fly.dev` gives you HTTPS for free,
    and the Tunnel becomes optional. [I]
  - Egress is $0.02/GB in NA/EU. [C]
  - Make sure `auto_stop_machines` is off.

**Railway.**
- Clean developer experience with usage billing: RAM $10/GB-month, vCPU
  $20/month, volumes $0.15/GB. [C] [railway-price]
- **The Hobby plan caps volumes at 5 GB** [C] [railway-vol]. That's fine for a
  100 MB vault, but too tight for 2 GB plus git history, which pushes you to Pro
  at a $20 minimum.
- There is "a small amount of downtime" on redeploy, because the old deployment
  stops before the new one starts. That is good for `ob`'s single-instance lock.
  Replicas are not allowed with volumes. [C]
- Backups: daily (6 days kept), weekly and monthly. [C] [railway-bk]
- Encryption is only asserted in a staff forum post (2024-06-18): data is
  "encrypted at-rest on the storage level", not per volume. [C2]

**Render.**
- The disk is encrypted, including its snapshots, and daily snapshots are kept
  ≥7 days. [C] [render-disk]
- It stops the old instance before starting the new one. [C]
- **But there's no 1 GB tier.** Starter is 512 MB for $7, and the next tier is
  Standard at 2 GB for $25. [C] [render-price] That makes it ~3x the cost of
  every other managed option.
- The Hobby workspace includes only 5 GB of bandwidth. [C]
- Not competitive here.

**Cloudflare Containers / Durable Objects.**
- Container "disk is ephemeral. When a Container instance goes to sleep… it will
  have a fresh disk", and `sleepAfter` defaults to 10 min. [C] [cf-containers]
  Containers are reachable only through a Worker or Durable Object.
- Durable Objects have SQLite/KV storage and no POSIX filesystem. [C] [cf-do]
- **Ruled out.** A fresh disk on wake would be a mass-delete trigger for `ob`.

## Networking and Cloudflare Tunnel

- `cloudflared` is outbound-only, so it works identically on every option above.
  [I]
- **On a VPS** the Tunnel lets you close every inbound port except SSH, or close
  SSH too and reach the host through the provider console or Tailscale.
- **On Fly/Render/Railway** the platform already terminates HTTPS. The Tunnel
  still matters as the way to put **Access Managed OAuth** in front
  ([claude-connector-mcp.md](claude-connector-mcp.md)).
  - If the platform hostname is also public, Access can be bypassed. You must
    either verify `Cf-Access-Jwt-Assertion` at the origin, which you should do
    anyway, or expose no public service at all. Fly makes the second option easy.
    [I]

## Ranked shortlist

1. **Fly.io, shared-cpu-1x 1 GB + 10 GB volume: ~$8/mo from October.**
   - It is the only option that is all of: node-local NVMe, encrypted by default,
     daily snapshots at effectively $0 (under 10 GB), managed runtime with no OS
     or SSH to patch, US or EU regions, and able to run with zero public ingress
     behind a Tunnel.
   - Costs: a Dockerfile and supervisor in the image, single-host volume downtime
     risk, and the "deploy may create a fresh empty volume" foot-gun. The startup
     guard covers that foot-gun, but it must be tested.
   - Bump to 2 GB (~$14) if measured memory demands it.
2. **Hetzner CX23: ~€7/mo with backups (EU only).**
   - 4 GB of RAM and 40 GB of local NVMe for the price of others' 1 GB, and a
     plain systemd host with the vault on the root disk, which is the simplest
     startup-safety story.
   - Costs: no provider encryption at rest, you patch the OS (unattended-upgrades),
     EU data residency, and a provider that has raised prices four times in 2026.
3. **Akamai/Linode Nanode 1 GB: $7/mo with backups.**
   - The pick if you want a US VPS with **default local-disk encryption**.
   - 1 GB is at the floor, and backups are stored unencrypted.

Not recommended:
- **Oracle:** idle reclaim, capacity.
- **GCP free:** 1 GB egress, 1 GB RAM.
- **Render:** no 1 GB tier, $25+.
- **Railway:** 5 GB Hobby volume cap, and unclear encryption.
- **DO / Vultr / Lightsail:** these are fine but dominated. Pick Linode for
  encryption, Hetzner for price, and Fly for managed.
- **Cloudflare:** impossible.

## Decision the owner must make

- **Managed container (Fly) vs self-patched VPS (Hetzner/Linode).**
  - Fly trades OS patching for image rebuilds plus platform quirks around volumes.
  - A VPS trades those quirks for owning the kernel, SSH, and unattended upgrades.
- **Is EU hosting acceptable?** If not, Hetzner drops out and Linode takes #2.
- **Is provider-managed encryption enough?** Every option's at-rest encryption
  uses keys the provider holds, so it protects against lost drives, not against
  the provider. Customer-held keys would need an unlock step on every reboot,
  which conflicts with unattended restart. [I]

## Sources (checked 2026-09-26)

- [hz-price] https://docs.hetzner.com/general/infrastructure-and-availability/price-adjustment/
- [hz-backup] https://docs.hetzner.com/cloud/servers/backups-snapshots/overview/
- Hetzner secondary (backup %, snapshot €/GB, IPv4 €0.50): https://costgoat.com/pricing/hetzner ; https://privatedevops.com/news/hetzner-june-2026-cloud-price-increase-what-to-do
- [do-price] https://www.digitalocean.com/pricing/droplets
- [do-srm] https://www.digitalocean.com/security/shared-responsibility-model-droplets
- DO IPv4 line item: https://docs.digitalocean.com/products/droplets/details/pricing/
- [linode-na] https://www.akamai.com/cloud/pricing/north-america
- [linode-enc] https://techdocs.akamai.com/cloud-computing/docs/local-disk-encryption
- Vultr (secondary; official page 403): https://costbench.com/software/cloud-infrastructure/vultr/ ; https://docs.vultr.com/vultr-vx1-cloud-compute
- [ls-price] https://aws.amazon.com/lightsail/pricing/
- [ls-bs] https://docs.aws.amazon.com/lightsail/latest/userguide/amazon-lightsail-faq-block-storage.html
- [oci-free] https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm
- OCI encryption: https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumeencryption.htm
- [gcp-free] https://docs.cloud.google.com/free/docs/free-cloud-features
- [fly-pricing-page] https://fly.io/pricing/
- [fly-price] https://docs.fly.io/about/pricing/
- [fly-update] https://fly.io/pricing-update/
- [fly-vol] https://docs.fly.io/volumes/overview/
- [fly-config] https://docs.fly.io/reference/configuration/ (mounts section)
- [railway-price] https://railway.com/pricing
- [railway-vol] https://docs.railway.com/reference/volumes
- [railway-bk] https://docs.railway.com/reference/backups
- Railway encryption (forum): https://station.railway.com/questions/are-databases-encrypted-at-rest-0e719d6c
- [render-price] https://render.com/pricing
- [render-disk] https://render.com/docs/disks
- [cf-containers] https://developers.cloudflare.com/containers/platform-details/
- [cf-do] https://developers.cloudflare.com/durable-objects/api/storage-api/
