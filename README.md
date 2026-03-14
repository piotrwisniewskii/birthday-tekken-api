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

2) Deploy to Minikube (manual / self-hosted)

- Location: `.github/workflows/deploy-to-minikube.yml`
- This workflow is intended to run on a self-hosted runner that already has `minikube`, `kubectl` and `helm` installed.
- It is manually triggered (workflow_dispatch) and accepts an `image_tag` input.
- The workflow executes `scripts/deploy-minikube.sh <image:tag>` which:
	- pulls the image from the registry
	- loads it into Minikube (`minikube image load`)
	- runs `helm upgrade --install` with the specified image tag

Local usage (dev):

You can also run the deploy script locally on a machine with `minikube` and `helm`:

```bash
# build and push image locally (or use the workflow)
docker build -t <docker_user>/birthday-tekken-api:mytag .
docker push <docker_user>/birthday-tekken-api:mytag

# then load and deploy to your local minikube
./scripts/deploy-minikube.sh <docker_user>/birthday-tekken-api:mytag
```

Notes
-----
- The repository currently expects secrets (DB and RabbitMQ) to be supplied via Kubernetes Secrets; do not keep sensitive credentials in `k8s/values.yaml` for production. Use sealed secrets or external secret stores when appropriate.
- The `deploy-to-minikube` workflow requires a self-hosted runner; if you prefer running it on GitHub-hosted runners consider using `kind`/`k3d` instead of Minikube, and edit the workflow accordingly.

Real-world, non-commercial use case
