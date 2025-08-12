# Birthday Tekken API

A Spring Boot application for managing Tekken character birthdays, deployed on Kubernetes with Istio.

## Deployment Status

The application is successfully deployed and running on Kubernetes.

## Components

- Spring Boot API
- PostgreSQL database
- Istio for service mesh and ingress

## Accessing the Application

To access your app:

1. Get the Istio ingress gateway IP:

```bash
kubectl get svc -n istio-system istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

2. Add the following entry to your `/etc/hosts` file:

```
<INGRESS_IP> birthday.local
```

3. Access the application at: http://birthday.local

## Deployment Process

The application is deployed using a CI/CD pipeline with:

1. Docker image build and push
2. Kubernetes namespace setup
3. Helm chart deployment
4. Deployment verification

## Kubernetes Resources

- Namespace: `birthday`
- Deployment: `birthday-api`
- Service: `birthday-api`
- PostgreSQL StatefulSet: `postgres`
- Istio Gateway and VirtualService

## Health Checks

The application provides a `/health` endpoint for Kubernetes probes.
