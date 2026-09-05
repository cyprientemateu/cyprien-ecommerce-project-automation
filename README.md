# 🛍️ 🚀 Revive E-Commerce Platform — GitOps / CD

The Helm chart and GitOps/CD side of the Revive e-commerce platform. This repo is deployed by [ArgoCD](https://argo-cd.readthedocs.io/) onto a local Kubernetes cluster (kind/minikube). Its companion repo, [`cyprien-ecommerce-project`](https://github.com/cyprientemateu/cyprien-ecommerce-project), owns the application source and CI pipeline that builds the images this repo deploys.

> The full engineering journal — why this rebuild happened, what was found in the legacy pipeline, phase-by-phase progress, and the roadmap — lives in the app repo: [`cyprien-ecommerce-project/docs/ENGINEERING_JOURNAL.md`](https://github.com/cyprientemateu/cyprien-ecommerce-project/blob/main/docs/ENGINEERING_JOURNAL.md). This README covers only what's specific to this repo.

## 🧭 What This Repo Is For

- Holds the Helm chart that defines how the six Revive services (`ui`, `catalog`, `cart`, `orders`, `checkout`, `assets`) and their datastores get deployed to Kubernetes
- Environment-specific values (`dev` vs `production`) as separate values files, applied by ArgoCD Applications
- Receives a `repository_dispatch` from the app repo's CI whenever new images are published, and updates the relevant values file so ArgoCD picks up the change

## ⚠️ Current State — Known Issues (being worked through the roadmap)

Being transparent about where this repo actually is right now, not where it's headed:

- **The chart is not yet a real Helm template.** `chart/templates/deploy.yaml` is a one-time hand-flattened dump of rendered manifests with only image-tag lines manually parameterized — not maintainable, and not what's described below as the target design. The fix (an umbrella chart depending on the app repo's already-well-built per-service charts under `do-it-yourself/helm-chart/`) is planned but not yet implemented.
- **Two committed secrets need rotation.** `deploy.yaml` currently contains two Kubernetes `Secret` objects (`catalog-db`, `orders-db`) with base64-encoded — **not encrypted** — real-looking database passwords. These must be treated as already-exposed credentials. Sealed Secrets is the planned replacement mechanism; until that lands, do not reuse these passwords anywhere real.
- **No ArgoCD Application manifests exist in this repo yet**, despite ArgoCD being the intended CD mechanism — the install documentation below was generic copy-pasted reference material, not a working setup.
- **A competing deploy path still exists.** The legacy `Jenkinsfile` in this repo runs `docker-compose down/pull/up` directly against a host, entirely separate from the Helm/ArgoCD path. It will be retired once ArgoCD is proven working; `docker-compose.yml` itself stays as local dev/demo tooling only.

See the app repo's journal for the full remediation plan and phase order.

## 🏗 Architecture (target state)

```text
                     repository_dispatch
cyprien-ecommerce-project  ─────────────────▶  this repo
  (CI: build, scan, sign)     {tag, environment}   │
                                                     │ bump values-<env>.yaml, commit
                                                     ▼
                                        ┌─────────────────────────┐
                                        │   Helm umbrella chart    │
                                        │  (chart/ + dependencies  │
                                        │   from app repo's        │
                                        │   per-service charts)    │
                                        └────────────┬─────────────┘
                                                     │ ArgoCD sync
                                                     ▼
                                        ┌─────────────────────────┐
                                        │   kind / minikube        │
                                        │   ui, catalog, cart,     │
                                        │   orders, checkout,      │
                                        │   assets + datastores    │
                                        └─────────────────────────┘
```

- **`dev`** environment: ArgoCD auto-sync + self-heal on every new image tag
- **`production`** environment: manual sync required — a deliberate "prod needs human approval" gate

## 📁 Project Structure

```text
cyprien-ecommerce-project-automation/
│
├── chart/
│   ├── Chart.yaml           # target: umbrella chart with per-service dependencies
│   ├── values.yaml           # shared defaults
│   ├── dev-values.yaml       # dev environment image tags
│   ├── branch-values.yaml    # legacy — planned for removal (see journal)
│   ├── production-values.yaml
│   └── templates/
│       ├── deploy.yaml       # legacy hand-flattened manifest — planned for removal
│       └── _helpers.tpl
│
├── docker-compose.yml         # local dev only, not a deployment path
├── Dockerfile                 # tiny yq/jq image, used by the legacy tag-bump Jenkins step
├── validate.sh                 # semver tag validator (vX.Y.Z), reused by the app repo's release job
└── README.md
```

## 🧰 Technologies Used

- Helm
- ArgoCD (planned install — not yet configured in this repo)
- kind / minikube
- Sealed Secrets (planned, for the two committed secrets)

## 🔐 Best Practices (planned / in progress)

- No plaintext or base64-only "secrets" committed to git — Sealed Secrets ciphertext only
- One chart, real templates, no hand-edited rendered YAML
- `dev` auto-syncs; `production` requires a manual approval step
- A single deployment mechanism (ArgoCD), not two competing ones

## ✍️ Maintainer
Cyprien Temateu
DevOps / DevSecOps — Cybersecurity Track
`Revive E-Commerce Platform`
