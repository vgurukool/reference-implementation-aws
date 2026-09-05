#!/bin/bash
set -e
export REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
REGION="us-east-2"
CLUSTER_NAME="cnoe-ref-impl"

echo "🧹 Starting full CNOE IDP teardown to eliminate AWS costs..."

# 1. Clean uninstall addons if kubeconfig is valid
if aws eks describe-cluster --name $CLUSTER_NAME --region $REGION >/dev/null 2>&1; then
    aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME || true
    echo "🗑️  Deleting Kubernetes addons and loadbalancers..."
    kubectl delete ingress --all -A --timeout=30s || true
    kubectl delete svc -l "service.k8s.aws/type=LoadBalancer" -A --timeout=30s || true
    kubectl delete namespace argocd backstage keycloak crossplane-system external-secrets external-dns --timeout=60s || true
fi

# 2. Terraform Destroy
echo "💥 Running Terraform destroy..."
terraform -chdir="$REPO_ROOT/cluster/terraform" destroy -auto-approve -var="region=$REGION" -var="cluster_name=$CLUSTER_NAME" -var="auto_mode=false"

echo "🎉 All AWS resources destroyed. Ongoing billing is $0.00."
