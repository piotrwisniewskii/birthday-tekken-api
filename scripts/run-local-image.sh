#!/usr/bin/env bash
set -euo pipefail

# Load an already-built image from a registry into Minikube and deploy via Helm.
# Usage: ./scripts/run-local-image.sh <image> [namespace]
# Example: ./scripts/run-local-image.sh piotruser/birthday-tekken-api:latest

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <image> [namespace]"
  exit 2
fi

IMAGE="$1"
NAMESPACE="${2:-birthday}"

echo ">>> Requirements: minikube, kubectl, helm, docker"
for cmd in minikube kubectl helm docker; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required command not found: $cmd" >&2
    exit 1
  fi
done

echo ">>> Starting minikube (if not running)"
if ! minikube status >/dev/null 2>&1; then
  minikube start --driver=docker --cpus=3 --memory=4g
fi

echo ">>> Pulling image: ${IMAGE}"
docker pull "${IMAGE}"

echo ">>> Loading image into Minikube"
minikube image load "${IMAGE}" || {
  echo "minikube image load failed, trying docker-env fallback"
  eval "$(minikube docker-env)"
  docker pull "${IMAGE}"
}

echo ">>> Creating namespace: ${NAMESPACE}"
kubectl create ns "${NAMESPACE}" 2>/dev/null || true

echo ">>> Deploying Helm chart with image ${IMAGE}"
# Split repo and tag
REPO="${IMAGE%%:*}"
TAG="${IMAGE#*:}"
helm upgrade --install birthday-tekken-api ./k8s -n "${NAMESPACE}" \
  --create-namespace --wait --timeout 5m \
  --set app.image.repository="${REPO}" \
  --set app.image.tag="${TAG}" \
  --set app.image.pullPolicy=IfNotPresent \
  --set postgresql.existingSecret=postgresql-auth

echo "Deployed ${IMAGE} to namespace ${NAMESPACE}"
kubectl -n "${NAMESPACE}" get pods -o wide
