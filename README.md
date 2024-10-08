# a1cyprien-do-it-yourself
## Revive Ecommerce App

Argo CD Installation Manifests
Four sets of installation manifests are provided:

Normal Installation:
install.yaml - Standard Argo CD installation with cluster-admin access. Use this manifest set if you plan to use Argo CD to deploy applications in the same cluster that Argo CD runs in (i.e. kubernetes.default.svc). Will still be able to deploy to external clusters with inputted credentials.

namespace-install.yaml - Installation of Argo CD which requires only namespace level privileges (does not need cluster roles). Use this manifest set if you do not need Argo CD to deploy applications in the same cluster that Argo CD runs in, and will rely solely on inputted cluster credentials. An example of using this set of manifests is if you run several Argo CD instances for different teams, where each instance will be deploying applications to external clusters. Will still be possible to deploy to the same cluster (kubernetes.default.svc) with inputted credentials (i.e. argocd cluster add <CONTEXT> --in-cluster --namespace <YOUR NAMESPACE>).

Note: Argo CD CRDs are not included into namespace-install.yaml. and have to be installed separately. The CRD manifests are located in manifests/crds directory. Use the following command to install them:

kubectl apply -k https://github.com/argoproj/argo-cd/manifests/crds\?ref\=stable
High Availability:
ha/install.yaml - the same as install.yaml but with multiple replicas for supported components.

ha/namespace-install.yaml - the same as namespace-install.yaml but with multiple replicas for supported components.