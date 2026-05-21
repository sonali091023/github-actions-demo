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

# ─────────────────────────────────────────────
# Remove old KIND cluster
# ─────────────────────────────────────────────

echo ""
echo "==== Removing Existing KIND Cluster ===="

kind delete cluster --name "$CLUSTER" || true

docker rm -f "${CLUSTER}-control-plane" || true

# ─────────────────────────────────────────────
# Disk usage after cleanup
# ─────────────────────────────────────────────

echo ""
echo "==== Disk Usage After Cleanup ===="
df -h

# ─────────────────────────────────────────────
# Create KIND cluster
# ─────────────────────────────────────────────

echo ""
echo "==== Creating KIND Cluster ===="

kind create cluster \
  --name "$CLUSTER" \
  --image "$KIND_NODE_IMAGE" \
  --config k8s/kind-config.yaml

# ─────────────────────────────────────────────
# Wait for nodes
# ─────────────────────────────────────────────

echo ""
echo "==== Waiting for Kubernetes nodes ===="

kubectl wait --for=condition=Ready nodes --all --timeout=300s

kubectl get nodes -o wide

# ─────────────────────────────────────────────
# Install NGINX Ingress Controller
# ─────────────────────────────────────────────

echo ""
echo "==== Installing NGINX Ingress Controller ===="

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# ─────────────────────────────────────────────
# Wait for ingress controller
# ─────────────────────────────────────────────

echo ""
echo "==== Waiting For Ingress Controller ===="

kubectl wait \
  --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

# ─────────────────────────────────────────────
# Build Backend
# ─────────────────────────────────────────────

echo ""
echo "==== Building Backend Image ===="

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
# Apply Kubernetes manifests
# ─────────────────────────────────────────────

echo ""
echo "==== Applying Kubernetes Manifests ===="

kubectl apply -f k8s/00-namespace.yaml

kubectl apply -f k8s/10-mysql.yaml

kubectl apply -f k8s/20-backend.yaml

kubectl apply -f k8s/30-frontend.yaml

kubectl apply -f k8s/40-ingress.yaml

# ─────────────────────────────────────────────
# Wait for MySQL
# ─────────────────────────────────────────────

echo ""
echo "==== Waiting for MySQL ===="

if ! kubectl wait \
  --for=condition=ready pod \
  -l app=mysql \
  -n "$NAMESPACE" \
  --timeout=300s; then

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

kubectl rollout status deployment/backend \
  -n "$NAMESPACE" \
  --timeout=300s

# ─────────────────────────────────────────────
# Wait for Frontend
# ─────────────────────────────────────────────

echo ""
echo "==== Waiting For Frontend Deployment ===="

kubectl rollout status deployment/frontend \
  -n "$NAMESPACE" \
  --timeout=300s

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
echo " Ingress Resources"
echo "========================================="

kubectl get ingress -n "$NAMESPACE"

echo ""
echo "========================================="
echo " SkillPulse Deployment Successful"
echo "========================================="

echo ""
echo "Frontend URL:"
echo "http://<EC2-PUBLIC-IP>/"

echo ""
echo "Backend API:"
echo "http://<EC2-PUBLIC-IP>/api"

echo ""