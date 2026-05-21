#!/usr/bin/env bash
set -e

CLUSTER="skillpulse"
NAMESPACE="skillpulse"

# Stable Kubernetes version
KIND_NODE_IMAGE="kindest/node:v1.30.0"

BACKEND_IMAGE="trainwithshubham/skillpulse-backend:latest"
FRONTEND_IMAGE="trainwithshubham/skillpulse-frontend:latest"

APP_DIR="/home/ubuntu/github-actions-demo"

echo "==== Pulling latest code ===="
cd "$APP_DIR"
git pull origin main

# ── Cleanup old Docker resources ───────────────────────────────────────
echo "==== Cleaning old Docker resources ===="
docker system prune -af || true

# ── Ensure KIND cluster is up ─────────────────────────────────────────
echo "==== Checking KIND cluster ===="

if ! kind get clusters | grep -wq "$CLUSTER"; then
  echo "Cluster not found — creating..."

  kind create cluster \
    --name "$CLUSTER" \
    --image "$KIND_NODE_IMAGE" \
    --config k8s/kind-config.yaml

else
  echo "Cluster $CLUSTER already exists"
fi

# ── Wait for cluster nodes ────────────────────────────────────────────
echo "==== Waiting for Kubernetes nodes ===="
kubectl wait --for=condition=Ready nodes --all --timeout=180s

# ── Build images ──────────────────────────────────────────────────────
echo "==== Building images ===="
docker build -t "$BACKEND_IMAGE" ./backend
docker build -t "$FRONTEND_IMAGE" ./frontend

# ── Load images into KIND node ────────────────────────────────────────
echo "==== Loading images into KIND ===="
kind load docker-image "$BACKEND_IMAGE" --name "$CLUSTER"
kind load docker-image "$FRONTEND_IMAGE" --name "$CLUSTER"

# ── Apply manifests in explicit order ─────────────────────────────────
echo "==== Applying manifests ===="

kubectl apply -f k8s/00-namespace.yaml \
              -f k8s/10-mysql.yaml \
              -f k8s/20-backend.yaml \
              -f k8s/30-frontend.yaml

# ── Wait for MySQL before backend restart ─────────────────────────────
echo "==== Waiting for MySQL ===="

kubectl rollout status statefulset/mysql \
  -n "$NAMESPACE" \
  --timeout=300s

# ── Restart deployments ───────────────────────────────────────────────
echo "==== Restarting deployments ===="

kubectl rollout restart deployment/backend -n "$NAMESPACE"
kubectl rollout restart deployment/frontend -n "$NAMESPACE"

# ── Wait for rollouts ─────────────────────────────────────────────────
echo "==== Waiting for rollouts ===="

kubectl rollout status deployment/backend \
  -n "$NAMESPACE" \
  --timeout=300s

kubectl rollout status deployment/frontend \
  -n "$NAMESPACE" \
  --timeout=180s

echo ""
echo "========================================="
echo " SkillPulse is live at:"
echo " http://localhost:8888"
echo "========================================="
echo ""