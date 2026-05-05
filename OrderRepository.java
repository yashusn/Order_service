---
# Argo CD Application — deploys order-service from gitops-config repo
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: order-service-dev
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: microservices

  source:
    repoURL: https://github.com/your-org/gitops-config.git
    targetRevision: HEAD
    path: apps/order-service/helm
    helm:
      releaseName: order-service
      valueFiles:
        - values.yaml
        - values-dev.yaml

  destination:
    server: https://kubernetes.default.svc
    namespace: dev

  syncPolicy:
    automated:
      prune: true        # Delete resources removed from Git
      selfHeal: true     # Revert manual kubectl changes
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
    retry:
      limit: 3
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m

  # Notify Slack on sync
  info:
    - name: team
      value: backend
