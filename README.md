# 🛍️ 🚀 Revive E-Commerce Platform — GitOps / CD

The Helm chart and GitOps/CD side of the Revive e-commerce platform. This repo is deployed by [ArgoCD](https://argo-cd.readthedocs.io/) onto a local Kubernetes cluster (kind). Its companion repo, [`cyprien-ecommerce-project`](https://github.com/cyprientemateu/cyprien-ecommerce-project), owns the application source, the per-service Helm charts vendored into this one, and the CI pipeline that builds the images this repo deploys.

> The full engineering journal — why this rebuild happened, what was found in the legacy pipeline, phase-by-phase progress including how the chart was actually debugged into a working state, and the roadmap — lives in the app repo: [`cyprien-ecommerce-project/docs/ENGINEERING_JOURNAL.md`](https://github.com/cyprientemateu/cyprien-ecommerce-project/blob/main/docs/ENGINEERING_JOURNAL.md). This README covers only what's specific to this repo.

## 🧭 What This Repo Is For

- Holds the umbrella Helm chart that deploys the six Revive services (`ui`, `catalog`, `carts`, `orders`, `checkout`, `assets`) and their five datastore subcharts (mariadb, dynamodb-local, redis, postgresql, rabbitmq) to Kubernetes
- Environment-specific values (`dev` vs `production`) as separate values files, applied by ArgoCD Applications
- Will receive a `repository_dispatch` from the app repo's CI whenever new images are published (the event fires today; the workflow here that should act on it isn't wired up yet — see Known Gaps)

## ✅ Current State

- **The chart is a real, working umbrella chart.** `chart/charts/` vendors all 11 per-service charts directly (copied from the app repo's `do-it-yourself/helm-chart/`, not resolved via `helm dependency update`), so a bare `git clone` of this repo is enough to `helm template`/`helm install` it — no cross-repo resolution needed at sync time. The old hand-flattened `templates/deploy.yaml` (and the two base64 "secrets" it had committed) is gone.
- **ArgoCD Applications exist and work.** `argocd/application-dev.yaml` (auto-sync + self-heal) and `argocd/application-production.yaml` (manual sync only) both point at this repo. `revive-dev` has been confirmed `Synced`/`Healthy` against a real kind cluster, with all 11 services running and connected end to end (`ui → catalog → mariadb` confirmed via an actual HTTP request, not just pod status).
- **Real deploy bugs found and fixed by actually running this**, not just by reading the YAML: four Bitnami datastore images had been pulled from public Docker Hub and needed repointing to the `bitnamilegacy` archive at a newer tag; rabbitmq's default auth user didn't match what `orders` connects as; five of six app charts' default `autoscaling.enabled: true` was silently overriding `replicaCount`; `carts`/`orders` (both JVM) were getting OOMKilled at the charts' default 256Mi limit. Full writeup in the journal's Session 7.

## ⚠️ Known Gaps

- **Two credentials are still plaintext-ish.** The vendored mariadb/postgresql subcharts ship a default password (`"testing"`) baked into their own `values.yaml` — not attacker-exposed in the sense of the old committed secrets, but not real secrets management either. Sealed Secrets is still the planned fix (see journal roadmap), not yet done.
- **No receiving workflow for `repository_dispatch` yet.** The app repo's CI fires the event successfully; nothing here listens for it. Image tag bumps into `values-dev.yaml` are still manual until that workflow is added.
- **A competing deploy path still exists.** The legacy `Jenkinsfile` in this repo runs `docker-compose down/pull/up` directly against a host, entirely separate from the Helm/ArgoCD path now proven working. Planned for retirement; `docker-compose.yml` itself stays as local dev/demo tooling only.
- **`revive-production`** Application exists but isn't yet pointed at a real release tag/branch — it tracks `main` as a placeholder.

See the app repo's journal for the full remediation plan and phase order.

## 🏗 Architecture

```text
                     repository_dispatch (fires; not yet consumed here)
cyprien-ecommerce-project  ─────────────────▶  this repo
  (CI: build, scan, sign)     {tag, environment}

                              chart/
                              ├── Chart.yaml
                              ├── values.yaml            (shared defaults)
                              ├── values-dev.yaml         (dev overlay)
                              ├── values-production.yaml  (prod overlay)
                              └── charts/                 (11 vendored subcharts)
                                    │
                                    │ ArgoCD sync (argocd/application-*.yaml)
                                    ▼
                        ┌─────────────────────────┐
                        │   kind (local)            │
                        │   ui, catalog, carts,     │
                        │   orders, checkout,       │
                        │   assets + datastores     │
                        └─────────────────────────┘
```

- **`dev`** environment (`revive-dev` namespace): ArgoCD auto-sync + self-heal
- **`production`** environment (`revive-production` namespace): manual sync required — a deliberate "prod needs human approval" gate

## 📁 Project Structure

```text
cyprien-ecommerce-project-automation/
│
├── argocd/
│   ├── application-dev.yaml         # auto-sync + self-heal
│   └── application-production.yaml  # manual sync only
│
├── chart/
│   ├── Chart.yaml
│   ├── values.yaml                  # shared defaults + cross-service fixes
│   ├── values-dev.yaml               # dev image tags, replicaCount, resource overrides
│   ├── values-production.yaml
│   └── charts/                       # 11 vendored subcharts (assets, carts, carts-db,
│                                      # catalog, catalog-db, checkout, checkout-db,
│                                      # orders, orders-db, rabbitmq, ui)
│
├── docker-compose.yml         # local dev only, not a deployment path
├── Dockerfile                 # tiny yq/jq image, used by the legacy tag-bump Jenkins step
├── validate.sh                 # semver tag validator (vX.Y.Z), reused by the app repo's release job
└── README.md
```

## 🧰 Technologies Used

- Helm 3 (umbrella chart, vendored subcharts)
- ArgoCD
- kind
- Sealed Secrets (planned)

## 🔐 Best Practices

- One real chart, no hand-edited rendered YAML
- `dev` auto-syncs; `production` requires a manual approval step
- A single deployment mechanism (ArgoCD) — the docker-compose deploy path is being retired

## ✍️ Maintainer
Cyprien Temateu
DevOps / DevSecOps — Cybersecurity Track
`Revive E-Commerce Platform`
