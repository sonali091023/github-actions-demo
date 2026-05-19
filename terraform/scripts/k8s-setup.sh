#!/bin/bash

set -euxo pipefail

exec > /var/log/userdata.log 2>&1

export DEBIAN_FRONTEND=noninteractive

# --------------------------------
# Update System
# --------------------------------
apt-get update -y
apt-get upgrade -y

apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  git \
  apt-transport-https

# --------------------------------
# Install Docker
# --------------------------------
install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
gpg --dearmor -o /etc/apt/keyrings/docker.gpg

chmod a+r /etc/apt/keyrings/docker.gpg

echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo $VERSION_CODENAME) stable" | \
tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y

apt-get install -y docker-ce docker-ce-cli containerd.io

systemctl enable docker
systemctl start docker

# Wait for Docker
until docker info; do
  sleep 3
done

usermod -aG docker ubuntu

# --------------------------------
# Install kubectl
# --------------------------------
curl -LO "https://dl.k8s.io/release/$(curl -L -s \
https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

rm -f kubectl

# --------------------------------
# Install KIND
# --------------------------------
curl -Lo /usr/local/bin/kind \
https://kind.sigs.k8s.io/dl/v0.29.0/kind-linux-amd64

chmod +x /usr/local/bin/kind

# --------------------------------
# Create KIND Cluster
# --------------------------------
if ! sudo -u ubuntu kind get clusters | grep -q skillpulse; then
  sudo -u ubuntu kind create cluster --name skillpulse
fi

# --------------------------------
# Configure kubectl
# --------------------------------
mkdir -p /home/ubuntu/.kube

cp /root/.kube/config /home/ubuntu/.kube/config

chown -R ubuntu:ubuntu /home/ubuntu/.kube

export KUBECONFIG=/home/ubuntu/.kube/config

# Wait for cluster readiness
until sudo -u ubuntu kubectl get nodes; do
  sleep 5
done

# --------------------------------
# Create Namespace
# --------------------------------
sudo -u ubuntu kubectl create namespace skillpulse \
--dry-run=client -o yaml | \
sudo -u ubuntu kubectl apply -f -

# --------------------------------
# Clone GitHub Repository
# --------------------------------
if [ ! -d "/home/ubuntu/github-actions-demo" ]; then
  sudo -u ubuntu git clone ${repo_url} /home/ubuntu/github-actions-demo
fi

chown -R ubuntu:ubuntu /home/ubuntu/github-actions-demo

# --------------------------------
# Deploy Kubernetes Resources
# --------------------------------
sudo -u ubuntu kubectl apply -f \
/home/ubuntu/github-actions-demo/k8s/

# --------------------------------
# Verify Deployment
# --------------------------------
sudo -u ubuntu kubectl get pods -A
