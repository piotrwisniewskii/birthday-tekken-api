#!/bin/bash
set -euo pipefail

# === USTAWIENIA ===
DOCKER_REPO="piowisni"           # Twój Docker Hub (login / org)
APP_NAME="birthday-tekken-api"
TAG="latest"
NAMESPACE="birthday"
CHART_PATH="./k8s"
RELEASE_NAME="${APP_NAME}"

APP_LABEL="birthday-api"         # label i nazwa Service/Deployment w chartcie
DEPLOY_NAME="birthday-api"
HOSTNAME="birthday.local"        # host z VirtualService

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

# === BUILD & PUSH IMAGE DO DOCKER HUB ===
IMAGE="${DOCKER_REPO}/${APP_NAME}:${TAG}"
echo ">> Building Docker image: ${IMAGE}"
docker build -t "${IMAGE}" .

echo ">> Pushing image to Docker Hub: ${IMAGE}"
docker push "${IMAGE}"

# === NAMESPACE + ISTIO INJECTION (idempotentnie) ===
echo ">> Ensuring namespace ${NAMESPACE} exists and is labeled for istio-injection..."
kubectl get namespace "${NAMESPACE}" &>/dev/null || kubectl create namespace "${NAMESPACE}"
kubectl label namespace "${NAMESPACE}" istio-injection=enabled --overwrite

# === HELM: UPGRADE / INSTALL ===
echo ">> Helm upgrade/install release '${RELEASE_NAME}' in namespace '${NAMESPACE}'..."
if helm list -n "${NAMESPACE}" 2>/dev/null | grep -q "^${RELEASE_NAME}\b"; then
  helm upgrade "${RELEASE_NAME}" "${CHART_PATH}" -n "${NAMESPACE}" \
    --set createNamespace=false \
    --set app.image.repository="${DOCKER_REPO}/${APP_NAME}" \
    --set app.image.tag="${TAG}" \
    --set app.image.pullPolicy="IfNotPresent"
else
  helm install "${RELEASE_NAME}" "${CHART_PATH}" -n "${NAMESPACE}" \
    --set createNamespace=false \
    --set app.image.repository="${DOCKER_REPO}/${APP_NAME}" \
    --set app.image.tag="${TAG}" \
    --set app.image.pullPolicy="IfNotPresent"
fi

# === ROLLOUT WAIT + DIAGNOSTYKA ===
echo ">> Waiting for rollout of deployment/${DEPLOY_NAME}..."
set +e
kubectl rollout status "deployment/${DEPLOY_NAME}" -n "${NAMESPACE}" --timeout=180s
rc=$?
set -e
if [[ $rc -ne 0 ]]; then
  echo "!! Rollout failed. Recent events and pod logs:"
  kubectl get events -n "${NAMESPACE}" --sort-by=.metadata.creationTimestamp | tail -20 || true
  kubectl get pods -n "${NAMESPACE}" -o wide || true
  POD=$(kubectl get pods -n "${NAMESPACE}" -l app="${APP_LABEL}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  [[ -n "${POD:-}" ]] && kubectl logs -n "${NAMESPACE}" "${POD}" --all-containers --tail=200 || true
  exit 1
fi

# === ISTIO: INFO I SZYBKI TEST ===
echo -e "\n>> Checking Istio Gateway/VirtualService..."
kubectl get gateway,virtualservice -n "${NAMESPACE}" || true

echo -e "\n>> Checking Istio ingress external IP..."
INGRESS_IP=$(kubectl get svc -n istio-system istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)

if [[ -n "${INGRESS_IP}" ]]; then
  echo "Istio Ingress external IP: ${INGRESS_IP}"
  echo "Dodaj do /etc/hosts:   ${INGRESS_IP}   ${HOSTNAME}"
  echo "Otwórz:                 http://${HOSTNAME}/"
  echo "Test:                   curl -v http://${HOSTNAME}/health"
else
  echo "Brak external IP (typowe dla Minikube)."
  echo "Użyj port-forward i Host header:"
  echo "  kubectl -n istio-system port-forward svc/istio-ingressgateway 8080:80"
  echo "  curl -v -H 'Host: ${HOSTNAME}' http://localhost:8080/health"
fi

echo -e "\n== Deployment complete =="
echo ""
echo "============================================================"
echo "🚀 Deployment zakończony pomyślnie!"
echo ""
echo "Aby uzyskać dostęp do aplikacji w Minikube z Istio:"
echo ""
echo "1) W osobnym terminalu uruchom:"
echo "   kubectl -n istio-system port-forward svc/istio-ingressgateway 8080:80"
echo ""
echo "2) W przeglądarce otwórz:"
echo "   http://localhost:8080/"
echo ""
echo "3) Sprawdzenie zdrowia aplikacji (health endpoint):"
echo "   curl -v http://localhost:8080/health"
echo ""
