# Pier — TODO / Roadmap

Pier's north star: a **complete native (iOS) replacement for the Komodo web UI** — everything you'd do in the web UI, doable in-app, with a native iOS feel (not a 1:1 visual copy of the web UI). Grounded in Komodo's own resource model and flow.

## Deferred Komodo resource types (intentionally skipped for now)

James doesn't currently use these, so they're not built yet. Documented here so we know what they are when we come back to them. (Descriptions from Komodo's docs — https://komo.do/docs/resources.)

| Resource | What it is | Typical actions |
|---|---|---|
| **Procedure** | Composes many Actions across other resource types into ordered, parallel **stages**. A way to orchestrate multi-step operations. | Run on button push or webhook trigger. |
| **Action** | A **TypeScript script that calls the Komodo API**, with a pre-initialized, type-aware Komodo client. Custom automation logic. | Write/edit script, run it. |
| **Build** | Builds application source (a Dockerfile-containing **git repo**) into a **Docker image** and pushes it to a configured registry. | Configure source/registry, run build. |
| **Repo** | Points at a **git repo**; can clone/pull it onto a Server or a Builder and run scripts or build binaries from it (automation, not necessarily Docker). | Clone, pull, run on-clone/on-pull commands. |
| **Swarm** | Configures the manager node(s) used to control a **Docker Swarm** — manage swarm nodes, stacks, services, tasks, configs, and secrets. Deployments/Stacks can attach to a Swarm. | Manage swarm nodes/services/etc. |
| **Resource Sync** | Declarative config: define resources (Deployments, Stacks, …) in **`.toml`** files and sync them; supports ordering via an `after` array. GitOps-style. | Sync, preview diff, apply. |
| **Builder** | Points to either a connected Server or an AWS instance; provides compute that **Builds** and **Repos** attach to. | Configure, attach to Build/Repo. |

When ready, each becomes a surface under **More** (or wherever fits), following the same container/VM/list/row conventions as the existing surfaces.

## Planned feature work (in progress / next)

- [ ] **Dashboard tab** (new, first tab) — Swift Charts. Komodo host metrics now; designed to later become a dashboard for **all** Pier services (NPM, SSH, …), not just Komodo.
- [ ] **Containers tab** — `TrawlSegmentBar` scope selector (All + one segment per server); hide the bar when only one server exists.
- [ ] **Terminals tab** (rename SSH → Terminals, make it the 3rd tab):
  - Sectioned list with a `TrawlSegmentBar` filter.
  - Top section: **SSH hosts** (existing behaviour).
  - Below: Komodo **server / container / stack / deployment** terminal targets.
  - The **+** button opens a menu: *SSH host* (existing sheet) + a *Komodo* section (server / container / stack / deployment) — each opens a sheet to configure that target.

## Parity backlog (Komodo web-UI features not yet in Pier)

- [ ] **Per-server Docker drill-down** — in Komodo, images/networks/volumes live *under* a Server. Fold Images (and add Networks/Volumes) into a Server detail screen; the top-level Images list with a server selector is an interim step.
- [ ] **Historical charts** on the Servers dashboard (`SystemStatsSample` model already exists for this).
- [ ] **Editable compose files** — `StacksViewModel.saveFile` exists but `StackEditorView` is still read-only.
- [ ] **Variables write** actions (create/edit/delete) — currently read-only; no client method yet.
- [ ] Update `NOTES.md` / `README.md` (still describe the Portainer era).
- [ ] `TrawlTests` target is known-broken (missing symbols) — unrelated, but blocks running the unit suite.
