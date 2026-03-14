#!/usr/bin/env bash
set -euo pipefail

# Simple local dev runner for the project.
# Usage: ./scripts/run-local.sh [image-tag]
# If image-tag is omitted, uses git short SHA or 'local'.

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT_DIR}"

IMAGE_REPO="${DOCKERHUB_USERNAME:-piotruser}"
TAG="${1:-$(git rev-parse --short HEAD 2>/dev/null || echo local)}"
IMAGE="${IMAGE_REPO}/birthday-tekken-api:${TAG}"
NAMESPACE="birthday"

echo ">>> Requirements: minikube, kubectl, helm, docker"
for cmd in minikube kubectl helm docker git; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required command not found: $cmd" >&2
    exit 1
  fi
done

echo ">>> Starting minikube (if not running)"
if ! minikube status >/dev/null 2>&1; then
  minikube start --driver=docker --cpus=3 --memory=4g
fi

echo ">>> Enabling ingress"
minikube addons enable ingress >/dev/null || true

echo ">>> Building project (maven)"
mvn -B -DskipTests clean package

echo ">>> Building docker image: ${IMAGE}"
docker build -t "${IMAGE}" .

echo ">>> Loading image into Minikube"
if minikube image load "${IMAGE}" >/dev/null 2>&1; then
  echo "Loaded image via minikube image load"
else
  echo "Fallback: using minikube docker-env"
  eval "$(minikube docker-env)"
  docker build -t "${IMAGE}" .
  # no need to unset env; user session continues
fi

echo ">>> Creating namespace: ${NAMESPACE}"
kubectl create ns "${NAMESPACE}" 2>/dev/null || true

# Read .env if present
ENV_FILE=".env"
if [ -f "${ENV_FILE}" ]; then
  echo ">>> Loading environment from ${ENV_FILE}"
  set -o allexport
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +o allexport
fi

# Create secrets if not exist
echo ">>> Ensuring secrets"
kubectl -n "${NAMESPACE}" get secret postgresql-auth >/dev/null 2>&1 || \
  kubectl -n "${NAMESPACE}" create secret generic postgresql-auth \
    --from-literal=username="${POSTGRES_USER:-postgres}" \
    --from-literal=password="${POSTGRES_PASSWORD:-postgrespw}" \
    --from-literal=database="${POSTGRES_DB:-birthdaydb}"

kubectl -n "${NAMESPACE}" get secret rabbitmq-auth >/dev/null 2>&1 || \
  kubectl -n "${NAMESPACE}" create secret generic rabbitmq-auth \
    --from-literal=username="${RABBIT_USER:-appuser}" \
    --from-literal=password="${RABBIT_PASSWORD:-apppass}" \
    --from-literal=vhost="${RABBIT_VHOST:-/}"

echo ">>> Deploying Helm chart"
helm upgrade --install birthday-tekken-api ./k8s -n "${NAMESPACE}" \
  --create-namespace \
  --wait --timeout 5m \
  --set app.image.repository="${IMAGE_REPO}/birthday-tekken-api" \
  --set app.image.tag="${TAG}" \
  --set app.image.pullPolicy=IfNotPresent \
  --set postgresql.existingSecret=postgresql-auth

MINIKUBE_IP="$(minikube ip)"
HOST="birthday.${MINIKUBE_IP}.sslip.io"

echo
echo "============================================================"
echo "Application should be available at: http://${HOST}/"
echo "To inspect pods: kubectl -n ${NAMESPACE} get pods -o wide"
echo "To view ingress: kubectl -n ${NAMESPACE} get ingress"
echo "============================================================"
