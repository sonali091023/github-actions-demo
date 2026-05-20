#!/bin/bash

set -euxo pipefail

exec > /var/log/userdata.log 2>&1

export DEBIAN_FRONTEND=noninteractive

# --------------------------------
# Update System
# --------------------------------
apt-get update -y
apt-get upgrade -y

apt-get install -y ca-certificates curl gnupg lsb-release git make apt-transport-https 

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

# --------------------------------   So using Makefile approach to install/configure KIND so commenting this
# Create KIND Cluster
# --------------------------------
#if ! sudo -u ubuntu kind get clusters | grep -q skillpulse; then
#  sudo -u ubuntu kind create cluster --name skillpulse
#fi

# --------------------------------   So using Makefile approach to install/configure kubectl so commenting this
# Configure kubectl
# --------------------------------
#mkdir -p /home/ubuntu/.kube
#sudo -u ubuntu kind get kubeconfig --name skillpulse > /home/ubuntu/.kube/config
#chown -R ubuntu:ubuntu /home/ubuntu/.kube
#export KUBECONFIG=/home/ubuntu/.kube/config
# Wait for cluster readiness
#until sudo -u ubuntu kubectl get nodes | grep -q " Ready"; do
#  sleep 5
#done

# --------------------------------   #So using Makefile approach to create namespace so commenting this
# Create Namespace
# --------------------------------
#sudo -u ubuntu kubectl create namespace skillpulse || true

# --------------------------------   #Commenting this to, As using Makefile approach
# Clone GitHub Repository
# --------------------------------
# Wait for cluster readiness
#until sudo -u ubuntu kubectl wait --for=condition=Ready nodes --all --timeout=120s; do
#  sleep 5
#done

# --------------------------------
# Clone GitHub Repository
# --------------------------------
repo_url="https://github.com/sonali091023/github-actions-repo.git"

if [ ! -d "/home/ubuntu/github-actions-demo" ]; then
  sudo -u ubuntu git clone "$repo_url" /home/ubuntu/github-actions-demo
fi

chown -R ubuntu:ubuntu /home/ubuntu/github-actions-demo

# --------------------------------
# Run Makefile Deployment
# --------------------------------

cd /home/ubuntu/github-actions-demo

#sudo -u ubuntu make apply
sudo -u ubuntu make up     #Even better Automation, To handle cluster creation by makefile use this, because make up already does: build, kind create cluster, load images, apply manifests etc.