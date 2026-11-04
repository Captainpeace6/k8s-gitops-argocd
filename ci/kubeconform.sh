#!/usr/bin/env bash
# Render the chart for every environment and validate the output against
# Kubernetes + CRD schemas (ServiceMonitor, PrometheusRule, Argo CD Application).
set -euo pipefail

K8S_VERSION="${K8S_VERSION:-1.30.0}"
CRDS='https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'

for env in dev prod; do
  echo "== charts/web-api ($env)"
  helm template web-api charts/web-api \
      -f charts/web-api/values.yaml -f "charts/web-api/values-$env.yaml" \
      --namespace "web-api-$env" \
    | kubeconform -strict -summary \
        -kubernetes-version "$K8S_VERSION" \
        -schema-location default -schema-location "$CRDS"
done

echo "== argocd/"
kubeconform -strict -summary -kubernetes-version "$K8S_VERSION" \
  -schema-location default -schema-location "$CRDS" argocd/
