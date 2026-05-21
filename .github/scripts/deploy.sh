#!/usr/bin/env bash
set -e

CLUSTER="skillpulse"
NAMESPACE="skillpulse"

KIND_NODE_IMAGE="kindest/node:v1.30.0"

BACKEND_IMAGE="sonali0910/skillpulse-backend:latest"
FRONTEND_IMAGE="sonali0910/skillpulse-frontend:latest"

APP_DIR="/home/ubuntu/github-actions-demo"

echo ""
echo "========================================="
echo "   SkillPulse Deployment Started"
echo "========================================="
echo ""

# ─────────────────────────────────────────────

# Pull latest code

# ─────────────────────────────────────────────

echo "==== Pulling latest code ===="

cd "$APP_DIR"

git fetch origin
git reset --hard origin/main

# ─────────────────────────────────────────────

# Show disk usage before cleanup

# ─────────────────────────────────────────────

echo ""
echo "==== Disk Usage Before Cleanup ===="
df -h

# ─────────────────────────────────────────────

# Docker Cleanup

# ─────────────────────────────────────────────

echo ""
echo "==== Cleaning Docker Resources ===="

docker system prune -af --volumes || true
docker builder prune -af || true
docker container prune -f || true
docker image prune -af || true
docker volume prune -f || true
docker network prune -f || true

# Optional: Remove old KIND node containers

echo ""
echo "==== Cleaning old KIND containers ===="

docker ps -a | grep "skillpulse" || true

# ─────────────────────────────────────────────

# Disk usage after cleanup

# ─────────────────────────────────────────────

echo ""
echo "==== Disk Usage After Cleanup ===="
df -h

# ─────────────────────────────────────────────

# Check KIND cluster

# ─────────────────────────────────────────────

echo ""
echo "==== Checking KIND cluster ===="

if kind get clusters | grep -wq "$CLUSTER"; then
echo "Cluster already exists"

echo ""
echo "==== Verifying cluster health ===="

if ! kubectl cluster-info >/dev/null 2>&1; then
echo "Cluster unhealthy. Recreating..."

kind delete cluster --name "$CLUSTER"

kind create cluster --name "$CLUSTER" --image "$KIND_NODE_IMAGE" --config k8s/kind-config.yaml

fi

else
echo "Cluster not found. Creating..."

kind create cluster --name "$CLUSTER" --image "$KIND_NODE_IMAGE" --config k8s/kind-config.yaml
fi

# ─────────────────────────────────────────────

# Wait for nodes

# ─────────────────────────────────────────────

echo ""
echo "==== Waiting for Kubernetes nodes ===="

kubectl wait --for=condition=Ready nodes --all --timeout=300s

kubectl get nodes -o wide

# ─────────────────────────────────────────────

# Build Backend

# ─────────────────────────────────────────────

echo ""
echo "==== Building Backend Image ===="
#Note: Important bash rule: If a command spans multiple lines, every line except the last must end with "\", Otherwise bash treats the next line as a new command.

docker build -t "$BACKEND_IMAGE" ./backend

# ─────────────────────────────────────────────

# Build Frontend

# ─────────────────────────────────────────────

echo ""
echo "==== Building Frontend Image ===="

docker build -t "$FRONTEND_IMAGE" ./frontend

# ─────────────────────────────────────────────

# Load images into KIND

# ─────────────────────────────────────────────

echo ""
echo "==== Loading Images Into KIND ===="

kind load docker-image "$BACKEND_IMAGE" --name "$CLUSTER"
kind load docker-image "$FRONTEND_IMAGE" --name "$CLUSTER"

# ─────────────────────────────────────────────

# Apply manifests

# ─────────────────────────────────────────────

echo ""
echo "==== Applying Kubernetes Manifests ===="

kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/10-mysql.yaml
kubectl apply -f k8s/20-backend.yaml
kubectl apply -f k8s/30-frontend.yaml

# ─────────────────────────────────────────────

# Wait for MySQL

# ─────────────────────────────────────────────

echo ""
echo "==== Waiting for MySQL ===="

if ! kubectl wait --for=condition=ready pod -l app=mysql -n "$NAMESPACE" --timeout=300s; then

echo ""
echo "========================================="
echo " MYSQL FAILURE DEBUG"
echo "========================================="

echo ""
kubectl get pods -n "$NAMESPACE" -o wide

echo ""
kubectl describe pod -l app=mysql -n "$NAMESPACE"

echo ""
echo "==== MYSQL LOGS ===="
kubectl logs -l app=mysql -n "$NAMESPACE" --tail=100 || true

echo ""
echo "==== DISK USAGE ===="
df -h

echo ""
echo "==== DOCKER USAGE ===="
docker system df || true

exit 1
fi

# ─────────────────────────────────────────────

# Wait for Backend

# ─────────────────────────────────────────────

echo ""
echo "==== Waiting For Backend Deployment ===="

kubectl rollout status deployment/backend -n "$NAMESPACE" --timeout=300s

# ─────────────────────────────────────────────

# Wait for Frontend

# ─────────────────────────────────────────────

echo ""
echo "==== Waiting For Frontend Deployment ===="

kubectl rollout status deployment/frontend -n "$NAMESPACE" --timeout=300s

# ─────────────────────────────────────────────

# Final Status

# ─────────────────────────────────────────────

echo ""
echo "========================================="
echo " Kubernetes Resources"
echo "========================================="

kubectl get all -n "$NAMESPACE"

echo ""
echo "========================================="
echo " SkillPulse Deployment Successful"
echo "========================================="
echo ""
echo "Frontend : http://localhost:8888"
echo ""
