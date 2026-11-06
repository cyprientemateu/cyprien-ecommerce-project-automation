# 🛍️ 🚀 Revive E-Commerce Platform — GitOps / CD

> **Status:** Active, in-progress project. Built incrementally; see the engineering journal for session-by-session history.

The Helm chart and GitOps/CD side of the Revive e-commerce platform. This repo is deployed by [ArgoCD](https://argo-cd.readthedocs.io/) onto a local Kubernetes cluster (kind). Its companion repo, [`cyprien-ecommerce-project`](https://github.com/cyprientemateu/cyprien-ecommerce-project), owns the application source, the per-service Helm charts vendored into this one, and the CI pipeline that builds the images this repo deploys.

> The full engineering journal — why this rebuild happened, what was found in the legacy pipeline, phase-by-phase progress including how the chart was actually debugged into a working state, and the roadmap — lives in the app repo: [`cyprien-ecommerce-project/docs/ENGINEERING_JOURNAL.md`](https://github.com/cyprientemateu/cyprien-ecommerce-project/blob/main/docs/ENGINEERING_JOURNAL.md). This README covers only what's specific to this repo.

## 🧭 What This Repo Is For

- Holds the umbrella Helm chart that deploys the six Revive services (`ui`, `catalog`, `carts`, `orders`, `checkout`, `assets`) and their five datastore subcharts (mariadb for catalog, a second MariaDB copy `orders-mariadb` for orders, dynamodb-local, redis, rabbitmq) to Kubernetes
- Environment-specific values (`dev` vs `production`) as separate values files, applied by ArgoCD Applications
- Will receive a `repository_dispatch` from the app repo's CI whenever new images are published (the event fires today; the workflow here that should act on it isn't wired up yet — see Known Gaps)

## ✅ Current State

- **The chart is a real, working umbrella chart.** `chart/charts/` vendors all 11 per-service charts directly (copied from the app repo's `do-it-yourself/helm-chart/`, not resolved via `helm dependency update`), so a bare `git clone` of this repo is enough to `helm template`/`helm install` it — no cross-repo resolution needed at sync time. The old hand-flattened `templates/deploy.yaml` (and the two base64 "secrets" it had committed) is gone.
- **ArgoCD Applications exist and work.** `argocd/application-dev.yaml` (auto-sync + self-heal) and `argocd/application-production.yaml` (manual sync only) both point at this repo. `revive-dev` has been confirmed `Synced`/`Healthy` against a real kind cluster, with all 11 services running. Verified by real requests, not pod status: `ui → catalog → mariadb`, and `orders → orders-db` (`/actuator/health` UP, `GET /orders` returns `[]`).
- **Real deploy bugs found and fixed by actually running this**, not just by reading the YAML: four Bitnami datastore images had been pulled from public Docker Hub and needed repointing to the `bitnamilegacy` archive at a newer tag; rabbitmq's default auth user didn't match what `orders` connects as; five of six app charts' default `autoscaling.enabled: true` was silently overriding `replicaCount`; `carts`/`orders` (both JVM) were getting OOMKilled at the charts' default 256Mi limit; and `orders` was wired to PostgreSQL although its image only ships the MariaDB JDBC driver, so it could never start (replaced with a MariaDB chart). Full writeup in the journal's Sessions 7 and 8.
- **GitOps behaviour verified in both directions** on a live kind cluster (journal Session 9, with screenshots): a Git commit (`replicaCount` 1 → 2 → 1) rolled out and back with no `kubectl` involved; a manual `kubectl scale` was reverted by ArgoCD `selfHeal` (the sync's `initiatedBy` was `{"automated":true}`); a manually deleted pod was recreated by Kubernetes' own ReplicaSet — a different layer from ArgoCD.
- **Verified by the application itself, not only by pod status:** `orders` returns `{"status":"UP"}` on `/actuator/health`, and a browser checkout produced a row in `CUSTOMER_ORDER` in `orders-db`.

## ⚠️ Known Gaps

- **No readiness probes on the app charts, so ArgoCD `Healthy` is weaker than it sounds.** Kubernetes marks a pod ready as soon as its container starts, so a JVM service (`orders`, `carts`) reads `1/1 Running` for the ~3 minutes it takes to boot under the dev CPU limits — and while crash-looping between restarts. Verify with `/actuator/health`, not the pod list.
- **ArgoCD polls Git (about every 3 minutes); there is no webhook.** A pushed change is not instantaneous. The UI's Refresh button, or `kubectl annotate application revive-dev -n argocd argocd.argoproj.io/refresh=normal`, forces a re-check.
- **The checkout service never forwards the cart to `orders`.** Upstream's `HttpOrdersService.ts` hardcodes `firstName: "John"`, `lastName: "Doe"` and `items: []`, so persisted orders have no line items. Inherited upstream behaviour, not a chart fault.
- **The datastores have no PersistentVolumeClaims here**, so data does not survive a pod restart (acceptable for a demo cluster).
- **Two credentials are still plaintext-ish.** The two vendored MariaDB subcharts (catalog-db, orders-db) ship a default password (`"testing"`) baked into their own `values.yaml` — not attacker-exposed in the sense of the old committed secrets, but not real secrets management either. Sealed Secrets is still the planned fix (see journal roadmap), not yet done.
- **No receiving workflow for `repository_dispatch` yet.** The app repo's CI fires the event successfully; nothing here listens for it. Image tag bumps into `values-dev.yaml` are still manual until that workflow is added.
- **Three legacy Jenkinsfiles and a competing deploy path still exist.** `Jenkinsfile`, `Jenkinsfile2`, and `Jenkinsfile-tag` are leftover Jenkins pipeline variants from before this repo moved to ArgoCD; `Jenkinsfile` specifically runs `docker-compose down/pull/up` directly against a host, entirely separate from the Helm/ArgoCD path now proven working. `Dockerfile` (a tiny yq/jq image) only exists to support `Jenkinsfile-tag`'s tag-bump step. All four are planned for retirement once ArgoCD fully replaces the Jenkins deploy path; `docker-compose.yml` itself stays as local dev/demo tooling only, independent of this cleanup.
- **The two secrets removed from `deploy.yaml` are still in this repo's git history.** They were upstream chart defaults (not unique production credentials), but are treated as compromised regardless and are not reused anywhere — removing them from history is cosmetic, not a real mitigation, so it isn't planned as separate work.
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
├── .gitattributes             # LF line endings everywhere (repo is edited from Windows and WSL)
├── docker-compose.yml         # local dev only, not a deployment path
├── .env                        # image tag vars for docker-compose - no secrets
├── Dockerfile                  # legacy: tiny yq/jq image, only used by Jenkinsfile-tag's tag-bump step
├── Jenkinsfile                 # legacy: docker-compose-based deploy, superseded by ArgoCD
├── Jenkinsfile2                 # legacy: an earlier build/dispatch variant
├── Jenkinsfile-tag              # legacy: semver-tagged release build, uses validate.sh
├── validate.sh                 # semver tag validator (vX.Y.Z) - still used, reused by the app repo's release job
└── README.md
```

## 🧪 Running It Locally (kind + ArgoCD)

The sequence used to bring this up by hand, from an empty cluster:

```bash
kind create cluster --name revive
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl get pods -n argocd -w            # wait for all 7 pods to be 1/1 Running
kubectl apply -f argocd/application-dev.yaml
```

`--server-side` is required: a plain `kubectl apply` fails on the `applicationsets` CRD with `metadata.annotations: Too long`.

Then log in to the ArgoCD UI and verify the app itself:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
kubectl -n argocd port-forward svc/argocd-server 8443:443      # https://localhost:8443, user "admin"
kubectl -n revive-dev port-forward svc/orders 8081:8080
curl localhost:8081/actuator/health                             # expect {"status":"UP",...}
```

The JVM services take about 3 minutes to start under the dev limits, so give them time before judging.

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
