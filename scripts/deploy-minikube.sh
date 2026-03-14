#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <image:tag> [namespace]"
  exit 1
fi

IMAGE="$1"
NAMESPACE="${2:-birthday}"
CHART_PATH="./k8s"

echo ">>> Deploying image: ${IMAGE} to namespace: ${NAMESPACE}"

echo ">>> Pulling image locally"
if ! docker pull "${IMAGE}"; then
  echo "Failed to pull ${IMAGE} from registry"
  exit 2
fi

echo ">>> Loading image into Minikube"
# Use minikube image load to make the image available to the cluster
if command -v minikube >/dev/null 2>&1; then
  if minikube image load "${IMAGE}" >/dev/null 2>&1; then
    echo "Image loaded into Minikube"
  else
    echo "minikube image load failed, attempting docker-env fallback"
    eval "$(minikube docker-env)"
    docker pull "${IMAGE}"
  fi
else
  echo "minikube not found in PATH"
  exit 3
fi

IMAGE_REPO="$(echo ${IMAGE} | cut -d: -f1)"
IMAGE_TAG="$(echo ${IMAGE} | cut -d: -f2-)"

echo ">>> Helm upgrade/install"
helm upgrade --install birthday-tekken-api "${CHART_PATH}" -n "${NAMESPACE}" \
  --create-namespace \
  --wait --timeout 5m \
  --set app.image.repository="${IMAGE_REPO}" \
  --set app.image.tag="${IMAGE_TAG}" \
  --set app.image.pullPolicy=IfNotPresent

echo ">>> Done"
