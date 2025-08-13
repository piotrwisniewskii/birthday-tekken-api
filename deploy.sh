#!/bin/bash
set -euo pipefail

# === USTAWIENIA ===
DOCKER_REPO="piowisni"
APP_NAME="birthday-tekken-api"
NAMESPACE="birthday"
CHART_PATH="./k8s"
RELEASE_NAME="${APP_NAME}"

APP_LABEL="birthday-api"
DEPLOY_NAME="birthday-api"
HOSTNAME="birthday.local"   # nieużywany gdy masz hosts: ["*"], ale zostawiam

# === WYMAGANIA ===
for bin in kubectl helm mvn docker; do
  command -v "$bin" >/dev/null || { echo "ERROR: missing '$bin'"; exit 1; }
done

# === SPRAWDŹ ISTIO CRDs ===
if ! kubectl get crd gateways.networking.istio.io &> /dev/null; then
  echo "ERROR: Istio CRDs nie znalezione."
  echo "Szybka instalacja (profil demo):"
  echo "  curl -L https://istio.io/downloadIstio | sh -"
  echo "  cd istio-* && ./bin/istioctl install --set profile=demo -y"
  echo "  kubectl label namespace ${NAMESPACE} istio-injection=enabled --overwrite"
  exit 1
fi

# === BUILD JAR ===
echo ">> Building Spring Boot app (skip tests)..."
mvn -q clean package -DskipTests

# === BUILD & PUSH IMAGE Z UNIKALNYM TAGIEM ===
NEW_TAG=$(date +%s)
IMAGE="${DOCKER_REPO}/${APP_NAME}:${NEW_TAG}"
echo ">> Building Docker image: ${IMAGE}"
docker build -t "${IMAGE}" .
echo ">> Pushing image to Docker Hub: ${IMAGE}"
docker push "${IMAGE}"

# === NAMESPACE + ISTIO INJECTION ===
echo ">> Ensuring namespace ${NAMESPACE} exists and is labeled for istio-injection..."
kubectl get namespace "${NAMESPACE}" &>/dev/null || kubectl create namespace "${NAMESPACE}"
kubectl label namespace "${NAMESPACE}" istio-injection=enabled --overwrite

# === HELM: UPGRADE / INSTALL (zawsze świeży tag + Always) ===
echo ">> Helm upgrade/install release '${RELEASE_NAME}' in namespace '${NAMESPACE}'..."
helm upgrade --install "${RELEASE_NAME}" "${CHART_PATH}" -n "${NAMESPACE}" \
  --set createNamespace=false \
  --set app.image.repository="${DOCKER_REPO}/${APP_NAME}" \
  --set app.image.tag="${NEW_TAG}" \
  --set app.image.pullPolicy="Always"

# === ROLLOUT WAIT + DIAGNOSTYKA ===
echo ">> Waiting for rollout of deployment/${DEPLOY_NAME}..."
set +e
kubectl rollout status "deployment/${DEPLOY_NAME}" -n "${NAMESPACE}" --timeout=180s
rc=$?
set -e
if [[ $rc -ne 0 ]]; then
  echo "!! Rollout failed. Recent events and pod logs:"
  kubectl get events -n "${NAMESPACE}" --sort-by=.metadata.creationTimestamp | tail -30 || true
  kubectl get pods -n "${NAMESPACE}" -o wide || true
  POD=$(kubectl get pods -n "${NAMESPACE}" -l app="${APP_LABEL}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  [[ -n "${POD:-}" ]] && kubectl logs -n "${NAMESPACE}" "${POD}" --all-containers --tail=200 || true
  exit 1
fi

# === ISTIO: INFO ===
echo -e "\n>> Checking Istio Gateway/VirtualService..."
kubectl get gateway,virtualservice -n "${NAMESPACE}" || true

echo -e "\n>> Checking Istio ingress external IP..."
INGRESS_IP=$(kubectl get svc -n istio-system istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)

echo -e "\n== Deployment complete =="

# === INSTRUKCJE KOŃCOWE ===
cat <<'TXT'

============================================================
🚀 Deployment zakończony pomyślnie!

Dostęp przez Istio (Minikube – bez external IP):

1) W osobnym terminalu uruchom port-forward:
   kubectl -n istio-system port-forward svc/istio-ingressgateway 8080:80

   Jeśli 8080 jest zajęty, użyj alternatywy:
   kubectl -n istio-system port-forward svc/istio-ingressgateway 8888:80

2) Test health (hosts: ["*"], więc bez nagłówków):
   curl -v http://localhost:8080/health
   # lub gdy użyłeś alternatywy:
   curl -v http://localhost:8888/health

3) UI:
   http://localhost:8080/
   # lub:
   http://localhost:8888/

API przykłady:
   # start turnieju
   curl -s -H "Content-Type: application/json" \
     -d '["piotr","lukasz","tomek","sromek"]' \
     http://localhost:8080/api/tournament/start | jq .

   # stan
   curl -s http://localhost:8080/api/tournament/state | jq .

   # lista meczów z DB
   curl -s http://localhost:8080/api/tournament/matches/all | jq .
============================================================
TXT
