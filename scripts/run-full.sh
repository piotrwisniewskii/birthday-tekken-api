#!/usr/bin/env bash
set -euo pipefail

# Full local runner for the project (build + deploy). 
# Usage: ./scripts/run-full.sh [image-tag]
# If image-tag is omitted, uses git short SHA or 'local'.

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT_DIR}"

IMAGE_REPO="${DOCKERHUB_USERNAME:-piotruser}"
TAG="${1:-$(git rev-parse --short HEAD 2>/dev/null || echo local)}"
IMAGE="${IMAGE_REPO}/birthday-tekken-api:${TAG}"
NAMESPACE="birthday"

echo ">>> Requirements: minikube, kubectl, helm, docker, git, mvn"
for cmd in minikube kubectl helm docker git mvn; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required command not found: $cmd" >&2
    exit 1
  fi
done

echo ">>> Ensure local Minikube and kubectl context"
if command -v minikube >/dev/null 2>&1; then
  # If Minikube is installed, make sure it's running and switch kubectl context to it
  if minikube status >/dev/null 2>&1; then
    echo ">>> Minikube appears to be running. Switching kubectl context to 'minikube' (if not already)."
    kubectl config use-context minikube >/dev/null 2>&1 || true
  else
    echo ">>> Minikube not running — starting Minikube"
    # Try to start; if start fails due to resource-change on existing profile,
    # delete and recreate the cluster automatically.
    START_OUTFILE="/tmp/minikube_start.out"
    if minikube start --driver=docker --cpus=3 --memory=4g >"${START_OUTFILE}" 2>&1; then
      kubectl config use-context minikube >/dev/null 2>&1 || true
    else
      start_err=$(cat "${START_OUTFILE}" 2>/dev/null || true)
      echo ">>> minikube start failed (see message)."
      # Detect common message about not being able to change resources
      if printf '%s' "$start_err" | grep -qiE "cannot change the (memory|cpus) for an existing|minikube.*already exists|must first delete the cluster"; then
        echo ">>> Detected existing Minikube profile with different resources. Deleting and recreating cluster..."
        minikube delete || true
        minikube start --driver=docker --cpus=4 --memory=6144 --wait=all
        kubectl config use-context minikube >/dev/null 2>&1 || true
      else
        echo ">>> minikube start failed for an unexpected reason. Showing last 200 chars of output:"
        echo "${start_err: -200}"
        exit 1
      fi
    fi
  fi

  echo ">>> Enabling ingress addon..."
  # Run in background — this call blocks in some minikube versions until pods are Ready.
  # We pre-pull images via host Docker first so the VM never has to reach registry.k8s.io cold.
  minikube addons enable ingress &
  INGRESS_ENABLE_PID=$!

  echo ">>> Pre-loading ingress-nginx images via host Docker (avoids slow pulls inside VM)..."
  # Wait just enough for the DaemonSet/Deployment manifests to be applied and pods scheduled.
  sleep 10
  INGRESS_IMAGES=$(kubectl get pods -n ingress-nginx \
    -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.image}{"\n"}{end}{range .spec.initContainers[*]}{.image}{"\n"}{end}{end}' \
    2>/dev/null | sort -u)
  if [ -n "$INGRESS_IMAGES" ]; then
    while IFS= read -r img; do
      [ -z "$img" ] && continue
      echo ">>> Pulling and loading: $img"
      docker pull "$img" 2>/dev/null \
        && minikube image load "$img" 2>/dev/null \
        && echo "    Loaded: $img" \
        || echo "    Warning: could not load $img (skipping)"
    done <<< "$INGRESS_IMAGES"
  else
    echo ">>> No ingress pods found yet — skipping image preload"
  fi

  # Wait for background enable to finish (should be quick now that images are preloaded)
  wait "$INGRESS_ENABLE_PID" 2>/dev/null || true

  echo ">>> Waiting for ingress-nginx controller to become ready (max 3 min)..."
  kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=180s 2>/dev/null \
    && echo ">>> Ingress controller is ready." \
    || echo ">>> Warning: ingress controller not ready yet, continuing anyway."
else
  echo ">>> Minikube not installed. The script will proceed using the current kubectl context."
fi

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
fi

echo ">>> Validating kubectl can reach the cluster"
# Wait for the API server to be ready (kubectl cluster-info may briefly fail)
WAIT_ATTEMPTS=12
WAIT_SLEEP=5
attempt=1
until kubectl cluster-info >/dev/null 2>&1; do
  if [ "$attempt" -ge "$WAIT_ATTEMPTS" ]; then
    echo "Error: kubectl cannot reach the configured cluster (current-context: $(kubectl config current-context 2>/dev/null || echo none))."
    echo "Give minikube more time or inspect 'minikube logs'."
    exit 1
  fi
  echo ">>> Waiting for kubectl to be able to contact the cluster (attempt ${attempt}/${WAIT_ATTEMPTS})..."
  attempt=$((attempt+1))
  sleep ${WAIT_SLEEP}
done

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

# NOTE: RabbitMQ secret (`rabbitmq-auth`) is created by the Helm chart
# (so Helm becomes the owner). Creating it beforehand without Helm
# ownership metadata will cause Helm to fail the install. We therefore
# do NOT create `rabbitmq-auth` here. If you already created it manually
# and Helm fails, delete it so Helm can create it:
#   kubectl -n ${NAMESPACE} delete secret rabbitmq-auth

if kubectl -n "${NAMESPACE}" get secret rabbitmq-auth >/dev/null 2>&1; then
  echo ">>> Warning: secret 'rabbitmq-auth' already exists in namespace ${NAMESPACE}."
  echo ">>> If Helm install fails with ownership/annotation errors, run: kubectl -n ${NAMESPACE} delete secret rabbitmq-auth"
fi

# If a user-created `rabbitmq-auth` exists but is NOT owned by Helm, back it up and remove it
if kubectl -n "${NAMESPACE}" get secret rabbitmq-auth >/dev/null 2>&1; then
  # Check for Helm ownership metadata
  managed_by=$(kubectl -n "${NAMESPACE}" get secret rabbitmq-auth -o jsonpath='{.metadata.labels.app\.kubernetes\.io/managed-by}' 2>/dev/null || true)
  release_name=$(kubectl -n "${NAMESPACE}" get secret rabbitmq-auth -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-name}' 2>/dev/null || true)
  release_ns=$(kubectl -n "${NAMESPACE}" get secret rabbitmq-auth -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-namespace}' 2>/dev/null || true)
  if [ -z "$managed_by" ] || [ "$managed_by" != "Helm" ] || [ -z "$release_name" ] || [ -z "$release_ns" ]; then
    echo ">>> Existing 'rabbitmq-auth' secret is not Helm-managed. Backing up and removing so Helm can create it."
    BACKUP_PATH="/tmp/rabbitmq-auth-backup-$(date +%s).yaml"
    kubectl -n "${NAMESPACE}" get secret rabbitmq-auth -o yaml > "$BACKUP_PATH" || true
    echo ">>> Backed up to $BACKUP_PATH"
    kubectl -n "${NAMESPACE}" delete secret rabbitmq-auth || true
  else
    echo ">>> 'rabbitmq-auth' already managed by Helm (release=${release_name}, namespace=${release_ns}), leaving it." 
  fi
fi

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
