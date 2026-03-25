#!/bin/bash

set -e

#echo "=== Delete existing cluster if exists ==="
#k3d cluster delete mycluster || true

echo "===Install Docker==="
sudo apt-get update -y
sudo apt-get install -y curl ca-certificates gnupg
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker ${SUDO_USER:-$USER}

echo "===Install Kubectl==="
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/kubectl

echo "===Install K3d==="
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

echo "===Create K3d Cluster==="
sudo k3d cluster create mycluster --port "8888:8888@loadbalancer" --port "8080:80@loadbalancer"

echo "===Waiting for cluster to be ready==="
sudo kubectl wait --for=condition=Ready node --all --timeout=60s

echo "===Create namespace==="
sudo kubectl create namespace argocd
sudo kubectl create namespace dev

# echo "===Install Helm==="
# if ! command -v helm &> /dev/null; then
#   echo "Installing Helm..."
#   curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
# fi

#echo '===Install ArgoCD with Helm==='

#helm repo add argo https://argoproj.github.io/argo-helm
#helm repo update

#helm install argocd argo/argo-cd \
  #-n argocd \
  #--create-namespace

#echo "===Waiting for ArgoCd to be ready==="
#kubectl wait --for=condition=available deployment \
 #   -l app.kubernetes.io/name=argocd-server \
  #  -n argocd --timeout=180s

echo "===Install ArgoCD with kubectl==="

sudo kubectl create namespace argocd || true
sudo kubectl apply -n argocd --server-side \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "===Waiting for ArgoCd to be ready==="
sudo kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=180s

echo "=== Apply ArgoCd Application==="
sudo kubectl apply -f $(dirname "$0")/../confs/argocd-app.yaml

echo "===Expose ArgoCd UI==="
sudo nohup kubectl port-forward svc/argocd-server -n argocd 8080:443 --address 0.0.0.0 > /dev/null 2>&1 &

echo ""
echo "======"
echo "Argo CD UI: https://localhost:8080"
echo "Login: admin"
echo -n "Password :"
sudo kubectl get secret argocd-initial-admin-secret \
    -n argocd \
    -o jsonpath="{.data.password}" | base64 -d
echo ""
echo "======"
echo ""

echo "===Done==="
sudo kubectl get nodes
sudo kubectl get ns
sudo kubectl get pods -n argocd
sudo kubectl get pods -n dev
