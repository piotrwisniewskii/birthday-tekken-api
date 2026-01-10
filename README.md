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

Real-world, non-commercial use case
