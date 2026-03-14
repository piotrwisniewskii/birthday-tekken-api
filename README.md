# Birthday Tekken API — repo demonstracyjne (DevOps-ready)

Krótko: aplikacja Java (Spring Boot) z przykładowym deploymentem na Kubernetes (Minikube). Repo zawiera:
- kod źródłowy aplikacji
- Dockerfile + maven wrapper (mvnw)
- Helm chart w katalogu `k8s/`
- skrypty pomocnicze i GitHub Actions do CI/CD

Poniżej znajdziesz instrukcję "one-command demo" dla osób, które chcą szybko odtworzyć cały stos lokalnie oraz opis plików i zalecenia DevOps.

## Diagram architektury

![Architecture](./docs/architecture.svg)

## Szybki start — lokalne demo (minikube)

Klonujesz repo, ustawiasz lokalne wartości (sekrety) i uruchamiasz jeden skrypt, który:
- uruchomi/upewni się, że Minikube działa
- zbuduje JAR (Maven) i obraz Dockera
- załaduje obraz do Minikube
- utworzy wymagane secrets
- wdroży Helm chart

1. Sklonuj repo i przejdź do katalogu:

```bash
git clone <repo-url>
cd birthday-tekken-api
```

2. Skopiuj przykład zmiennych środowiskowych i dopasuj hasła (NIE commituj .env):

```bash
cp .env.example .env
# edytuj .env i wpisz mocne hasła
```

3. Uruchom demo (wymagane: docker, minikube, helm, kubectl, mvn):

```bash
./scripts/run-local.sh
```

Po kilku minutach aplikacja powinna być dostępna pod adresem pokazanym w konsoli (np. birthday.<minikube-ip>.sslip.io).

## CI / CD

- `/.github/workflows/build-and-push.yml` — automatyczne budowanie artefaktu i wypychanie obrazu do rejestru (Docker Hub / GHCR). Wymaga sekretów: `DOCKERHUB_USERNAME` i `DOCKERHUB_TOKEN`.
- `/.github/workflows/deploy-to-minikube.yml` — ręczny (workflow_dispatch) deploy na self-hosted runnerze z Minikube. Używa `scripts/deploy-minikube.sh`.

Jeśli chcesz pokazać automatyczny pokaz (CI → deploy), mogę zintegrować automatyczny job, ale wymaga to wyboru: deploy na self-hosted Minikube lub użycie `kind`/`k3d` na GitHub-hosted runnerze.

## Jak zbudować i opublikować obraz ręcznie

```bash
mvn -B -DskipTests clean package
docker build -t <docker_user>/birthday-tekken-api:<tag> .
docker push <docker_user>/birthday-tekken-api:<tag>
helm package k8s
./scripts/run-full.sh
```

## Audyt plików (co zostawić, co można usunąć)

Poniżej krótka lista plików/ folderów na najwyższym poziomie i moje rekomendacje:

- `Dockerfile` — ZOSTAW. Potrzebny do budowy obrazu.
- `pom.xml` — ZOSTAW. Główna konfiguracja Maven.
- `mvnw` / `mvnw.cmd` / `.mvn/` — ZOSTAW. Maven Wrapper zapewnia spójne buildy na CI i u innych deweloperów (warto trzymać).
- `k8s/` — ZOSTAW. Helm chart i manifesty do deploymentu (kluczowe dla demonstracji DevOps).
- `.github/workflows/` — ZOSTAW. Pokazują pipeline i CI.
- `scripts/` — ZOSTAW. Skrypty pomocnicze (run-local.sh, deploy-minikube.sh).
- `.gitattributes` — ZOSTAW. Przydatne do normalizacji końcówek linii i eksportów.
- `.gitignore` — ZOSTAW.
- `.env.example` — ZOSTAW. Pokazuje wymagane zmienne.

Pliki, które prawdopodobnie nie powinny być w repo (sprawdź, nie są śledzone przez Git jeśli nie trzeba):
- `target/` — katalog buildów (powinien być w .gitignore); nie commituj go.
- edytorowe pliki typu `*.swp` lub `.deploy.sh.swo` — usuń lokalnie i dodaj do .gitignore jeśli się pojawiają.
- IDE lokalne (`.idea/`) — nie trzymać w repo (dodaj do .gitignore jeśli jeszcze nie ma).

Jeśli chcesz czystą historię dla pokazu, mogę przygotować polecenia (`git rm --cached` / .gitignore update) i skrócić historię PR przed pokazem.

## Dalsze ulepszenia (opcjonalne, polecam)
- Dodać `Makefile` z wygodnymi targetami (`make build`, `make run-local`, `make clean`).
- Dodać GitHub Action, które tworzy Release i dołącza `chart.tgz` jako asset po każdym tagu — wtedy wystarczy udostępnić link do Release zamiast całego repo.
- Dodać SealedSecrets / ExternalSecrets do bezpiecznej prezentacji wartości w demonstracji (bez powielania haseł).

---

Jeżeli chcesz, przygotuję też:
- `Makefile` + krótkie instrukcje,
- automatyczne publikowanie `chart.tgz` do GitHub Release po CI,
- prostą stronę demo (static) z instrukcją i linkami (np. GitHub Pages).

Powiedz co chcesz dodać dalej — przygotuję i zaaplikuję zmiany.
Birthday Tekken API – Kubernetes Demo Project

Birthday Tekken API is a backend application written in Java, running in a Kubernetes environment (Minikube).
The application is deployed using a Kubernetes Deployment that pulls a prebuilt container image of the application.

The API is responsible for creating and managing a tournament bracket for the game Tekken.

This project was inspired by a long-standing personal tradition — every year on my birthday, my friends and I meet to organize a Tekken tournament.
The application automates the tournament setup process, removing the need for manual bracket creation and participant management.

🧱 Architecture

Kubernetes (Minikube) – local Kubernetes cluster

Deployment – manages the application lifecycle

Docker Image – Birthday Tekken API

Java Backend – tournament bracket generation logic

The application is designed as a lightweight containerized service, making it easy to develop locally and ready for future migration to cloud environments (e.g. AKS).

🚀 Project Goals

Hands-on practice with Kubernetes and containerization

Understanding Deployments, Services, and K8s fundamentals

Foundation for further DevOps / DevSecOps learning

CI / Deployment workflows
------------------------

There are two recommended pipelines in this repository:

1) Build and push (GitHub Actions)

- Location: `.github/workflows/build-and-push.yml`
- On push to `main` it will:
	- run `mvn package` to build the artifact
	- build a Docker image and push it to Docker Hub as
		`${{ secrets.DOCKERHUB_USERNAME }}/birthday-tekken-api:${{ github.sha }}` and `:latest`

	Required repository secrets:
	- `DOCKERHUB_USERNAME` — your Docker Hub user/org
	- `DOCKERHUB_TOKEN` — a Docker Hub access token (or password)

2) Manual deploy options

- Hosted (recommended for demos): `.github/workflows/deploy-to-k3d.yml` — a manual (workflow_dispatch) job that runs on GitHub-hosted runners, creates a k3d cluster, imports a specified image and runs the Helm chart. Use this for a reproducible demo without a self-hosted runner.

- Local (developer): use `./scripts/run-local-image.sh <image:tag>` to pull an image, load it into your local Minikube and deploy the Helm chart. This is the simple local path when you already pushed an image to a registry.

Local usage (dev):

You can build and push an image, then deploy it locally:

```bash
# build and push image locally (or use the build-and-push workflow)
mvn -B -DskipTests clean package
docker build -t <docker_user>/birthday-tekken-api:mytag .
docker push <docker_user>/birthday-tekken-api:mytag

# then load and deploy to your local minikube
./scripts/run-local-image.sh <docker_user>/birthday-tekken-api:mytag
```

Notes
-----
- The repository currently expects secrets (DB and RabbitMQ) to be supplied via Kubernetes Secrets; do not keep sensitive credentials in `k8s/values.yaml` for production. Use sealed secrets or external secret stores when appropriate.
- The `deploy-to-minikube` workflow requires a self-hosted runner; if you prefer running it on GitHub-hosted runners consider using `kind`/`k3d` instead of Minikube, and edit the workflow accordingly.

Real-world, non-commercial use case
