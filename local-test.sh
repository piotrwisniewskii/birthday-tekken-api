#!/bin/bash
set -e

NAMESPACE="birthday"

echo "Checking pod status..."
kubectl get pods -n ${NAMESPACE}

echo "\nChecking Istio gateway status..."
kubectl get gateway -n ${NAMESPACE}

echo "\nChecking VirtualService status..."
kubectl get virtualservice -n ${NAMESPACE}

echo "\nGetting Istio ingress gateway IP..."
INGRESS_IP=$(kubectl get svc -n istio-system istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$INGRESS_IP" ]; then
  echo "No external IP found for Istio ingress gateway. You might be using Minikube or a local cluster."
  echo "Setting up port-forwarding for local testing..."

  # Kill any existing port-forward on port 8080
  lsof -ti:8080 | xargs kill -9 2>/dev/null || true

  # Start port-forwarding in the background
  kubectl port-forward -n ${NAMESPACE} svc/birthday-api 8080:8080 &
  PORT_FORWARD_PID=$!

  echo "Port forwarding started with PID $PORT_FORWARD_PID"
  echo "Access your application at: http://localhost:8080"
  echo "Press Ctrl+C to stop port forwarding"

  # Wait for port-forwarding to be stopped
  wait $PORT_FORWARD_PID
else
  echo "\nIstio Ingress Gateway IP: $INGRESS_IP"
  echo "Add the following entry to your /etc/hosts file:\n$INGRESS_IP birthday.local"
  echo "\nThen access your application at: http://birthday.local"

  echo "\nWould you like to update your hosts file now? (y/n)"
  read -r response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    # Check if the entry already exists
    if grep -q "birthday.local" /etc/hosts; then
      sudo sed -i "s/.*birthday.local/$INGRESS_IP birthday.local/" /etc/hosts
      echo "Updated existing entry in /etc/hosts"
    else
      echo "$INGRESS_IP birthday.local" | sudo tee -a /etc/hosts > /dev/null
      echo "Added new entry to /etc/hosts"
    fi
  fi

  echo "\nTesting connection to the application..."
  curl -v http://birthday.local/health
fi
