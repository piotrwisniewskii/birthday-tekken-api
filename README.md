# Birthday Tekken API

Spring Boot API do zarzadzania turniejem Tekken. Projekt zawiera backend, prosty frontend, PostgreSQL, RabbitMQ, Docker i deployment na Kubernetes przez Helm.

## Co jest w repo

- `src/` - kod aplikacji i statyczny frontend
- `Dockerfile` - budowa obrazu aplikacji
- `k8s/` - chart Helm z aplikacja, PostgreSQL, RabbitMQ i Ingress
- `scripts/run-full.sh` - lokalny deployment end-to-end na Minikube
- `.github/workflows/` - CI do testow, skanu podatnosci i pushu obrazu

## Jak to dziala

- aplikacja startuje jako Spring Boot na porcie 8080
- dane sa zapisywane w PostgreSQL
- eventy turniejowe sa publikowane do RabbitMQ
- Helm stawia caly stos w namespace `birthday`

## Szybki start lokalnie

Wymagania:

- Docker
- Minikube
- `kubectl`
- Helm

Uruchom:

```bash
./scripts/run-full.sh
```

Skrypt robi wszystko automatycznie:

- uruchamia albo naprawia Minikube
- buduje aplikacje i obraz Dockera
- laduje obraz do Minikube
- przygotowuje sekrety potrzebne do deploymentu
- wykonuje `helm upgrade --install`
- wypisuje adres aplikacji

## CI i Docker Hub

Workflow `.github/workflows/build-and-push.yml` uruchamia sie po pushu do `main` i wykonuje:

1. testy Maven
2. skan zaleznosci przez Trivy dla aktualnego commita
3. upload raportu `dependency-scan-report`
4. push obrazu do Docker Huba tylko wtedy, gdy testy i skan przeszly

To oznacza:

- na GitHub mozna pushowac zawsze
- do Docker Huba obraz idzie tylko wtedy, gdy nie ma podatnosci `HIGH` albo `CRITICAL`

Wymagane sekrety GitHub Actions:

- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`

## Deployment lokalny

Najwazniejsze pliki chartu Helm:

- `k8s/templates/app-deployment.yaml` - aplikacja Spring Boot
- `k8s/templates/postgres-deployment.yaml` - PostgreSQL
- `k8s/templates/rabbitmq.yaml` - RabbitMQ z management UI
- `k8s/templates/ingress.yaml` - publiczny host dla aplikacji w klastrze

## Przydatne komendy

```bash
./mvnw clean verify
kubectl get pods -n birthday
kubectl get ingress -n birthday
kubectl port-forward svc/rabbitmq 15672:15672 -n birthday
```
