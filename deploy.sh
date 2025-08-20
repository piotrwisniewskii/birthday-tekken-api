#!/usr/bin/env bash
set -euo pipefail

APP_NAME="birthday-tekken-api"
RELEASE_NAME="${APP_NAME}"
NAMESPACE="birthday"
CHART_PATH="./k8s"

need_minikube_start=false
if ! command -v minikube >/dev/null 2>&1; then
  echo "❌ Brak minikube w PATH. Zainstaluj minikube i uruchom ponownie."
  exit 1
fi

if ! minikube status >/dev/null 2>&1; then
  need_minikube_start=true
fi

if $need_minikube_start; then
  echo ">>> Uruchamiam świeży klaster minikube (driver=docker, 4 CPU, 6GB RAM)"
  minikube start --driver=docker --cpus=4 --memory=6g
fi

echo ">>> Włączam addon Ingress (NGINX)"
minikube addons enable ingress >/dev/null

echo ">>> Czekam na gotowość kontrolera Ingress..."
kubectl -n ingress-nginx wait --for=condition=Available deploy/ingress-nginx-controller --timeout=180s

kubectl create ns "${NAMESPACE}" 2>/dev/null || true
kubectl label ns "${NAMESPACE}" istio-injection- --overwrite 2>/dev/null || true

MINIKUBE_IP="$(minikube ip)"
HOST="birthday.${MINIKUBE_IP}.sslip.io"

echo ">>> Użyję hosta Ingress: ${HOST}"

helm upgrade --install "${RELEASE_NAME}" "${CHART_PATH}" -n "${NAMESPACE}" \
  --set ingress.enabled=true \
  --set ingress.className=nginx \
  --set ingress.host="${HOST}"

echo ">>> Czekam na gotowość aplikacji..."
kubectl -n "${NAMESPACE}" rollout status deploy/birthday-api --timeout=5m

echo
echo "============================================================"
echo "URL:  http://${HOST}/"
echo "Podgląd Ingress:"
kubectl -n "${NAMESPACE}" get ingress

echo "teraz, w przeglądarce wprowadź http://birthday.192.168.49.2.sslip.io/ i gotowe :)"
echo "============================================================"

