#!/bin/bash
set -e

# Variables
DOCKER_REPO="piowisni" # Use your Docker Hub username or container registry
APP_NAME="birthday-tekken-api"
TAG="latest"
NAMESPACE="birthday"

# Check if Istio is installed
if ! kubectl get crd gateways.networking.istio.io &> /dev/null; then
  echo "ERROR: Istio CRDs are not installed in your cluster."
  echo "You need to install Istio first before deploying this application."
  echo "Run the following commands to install Istio:"
  echo "1. curl -L https://istio.io/downloadIstio | sh -"
  echo "2. cd istio-*"
  echo "3. ./bin/istioctl install --set profile=demo -y"
  echo "4. kubectl label namespace ${NAMESPACE} istio-injection=enabled --overwrite"
  exit 1
fi

# Build app and docker image
echo "Building Spring Boot app..."
mvn clean package -DskipTests
echo "Building Docker image..."
docker build -t ${DOCKER_REPO}/${APP_NAME}:${TAG} .
docker push ${DOCKER_REPO}/${APP_NAME}:${TAG}

# Update image in Helm values if needed
# Uncomment these lines if you're changing the repository or tag
# sed -i "s|repository:.*|repository: ${DOCKER_REPO}/${APP_NAME}|" k8s/values.yaml
# sed -i "s|tag:.*|tag: ${TAG}|" k8s/values.yaml

# More robust approach with direct namespace management
echo "Setting up namespace ${NAMESPACE}..."

# First handle the namespace directly with kubectl
if kubectl get namespace ${NAMESPACE} &> /dev/null; then
  echo "Namespace ${NAMESPACE} already exists, ensuring it has correct labels..."
  kubectl label namespace ${NAMESPACE} istio-injection=enabled --overwrite
else
  echo "Creating namespace ${NAMESPACE}..."
  kubectl create namespace ${NAMESPACE}
  kubectl label namespace ${NAMESPACE} istio-injection=enabled
fi

# Check Helm release status
if helm list -n ${NAMESPACE} 2>/dev/null | grep -q "${APP_NAME}"; then
  echo "Upgrading existing Helm release..."
  helm upgrade ${APP_NAME} ./k8s -n ${NAMESPACE} --set createNamespace=false
else
  echo "Installing new Helm release..."
  helm install ${APP_NAME} ./k8s -n ${NAMESPACE} --set createNamespace=false
fi

# Give the resources time to be created
echo "Waiting for resources to be created..."
sleep 20

# Verify deployment with more robust approach
echo "Checking deployment status..."
if kubectl get deployment birthday-api -n ${NAMESPACE} &>/dev/null; then
  echo "Deployment found, waiting for rollout..."

  # First check if there are any pending pods
  echo "Checking for pending pods..."
  kubectl get pods -n ${NAMESPACE} -l app=birthday-api

  # Check for any events that might indicate issues
  echo "Recent events in namespace:"
  kubectl get events -n ${NAMESPACE} --sort-by=.metadata.creationTimestamp | tail -10

  # Check for container logs to debug issues
  echo "Checking container logs for any running pods:"
  POD=$(kubectl get pods -n ${NAMESPACE} -l app=birthday-api -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -n "$POD" ]; then
    echo "Pod logs for $POD:"
    kubectl logs -n ${NAMESPACE} $POD --all-containers || echo "Could not get logs"
  fi

  # Try to wait for the rollout with an increased timeout, but add --timeout=0 to skip timeout
  kubectl rollout status deployment/birthday-api -n ${NAMESPACE} --timeout=0

  # If still having issues, get pod logs
  if [ $? -ne 0 ]; then
    echo "Deployment is having issues. Getting pod logs:"
    POD_NAME=$(kubectl get pods -n ${NAMESPACE} -l app=birthday-api -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$POD_NAME" ]; then
      kubectl logs -n ${NAMESPACE} $POD_NAME
    else
      echo "No pods found to get logs from."
    fi
  fi
else
  echo "Warning: Deployment 'birthday-api' not found in namespace '${NAMESPACE}'"
  echo "Current deployments in namespace:"
  kubectl get deployments -n ${NAMESPACE}
fi

# Check Istio configuration
echo "\nChecking Istio configuration..."
echo "Gateway:"
kubectl get gateway -n ${NAMESPACE}
echo "VirtualService:"
kubectl get virtualservice -n ${NAMESPACE}

# Get ingress IP and test connection
echo "\nGetting Istio ingress gateway IP..."
INGRESS_IP=$(kubectl get svc -n istio-system istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -n "$INGRESS_IP" ]; then
  echo "Istio Ingress Gateway IP: $INGRESS_IP"
  echo "\nYou can access your app at: http://birthday.local"
  echo "Add the following entry to your /etc/hosts file:\n$INGRESS_IP birthday.local"

  echo "\nTesting connection to the application..."
  echo "(This might fail if you haven't updated your hosts file yet)"
  curl -m 5 -v http://birthday.local/health || echo "\nCouldn't connect to the application yet. Make sure to update your hosts file."
else
  echo "\nNo external IP found for Istio ingress gateway."
  echo "If you're using Minikube or a local cluster, you can use port-forwarding:"
  echo "kubectl port-forward -n ${NAMESPACE} svc/birthday-api 8080:8080"
  echo "Then access your application at http://localhost:8080"
  echo "\nOr run the included local-test.sh script for automated setup."
fi

echo "\nDeployment complete! See access-instructions.md for detailed connection instructions."
