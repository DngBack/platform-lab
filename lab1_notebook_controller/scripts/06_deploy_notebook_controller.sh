#!/bin/bash

# Script: Deploy Notebook Controller Only
# Description: Deploy chỉ Notebook Controller (không cần full Kubeflow)

set -e

echo "========================================"
echo "Deploying Notebook Controller (Standalone)"
echo "========================================"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_info() { echo -e "${YELLOW}➜ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }

# Configuration
MANIFESTS_DIR="./manifests"
NOTEBOOK_CONTROLLER_PATH="$MANIFESTS_DIR/apps/jupyter/notebook-controller/upstream"

# Check if manifests directory exists
if [ ! -d "$MANIFESTS_DIR" ]; then
    print_error "Manifests directory not found!"
    echo "Please run ./scripts/02_deploy_kubeflow.sh first to clone manifests,"
    echo "or manually clone: git clone https://github.com/kubeflow/manifests.git"
    exit 1
fi

# Check if notebook-controller manifests exist
if [ ! -d "$NOTEBOOK_CONTROLLER_PATH" ]; then
    print_error "Notebook controller manifests not found!"
    echo "Expected path: $NOTEBOOK_CONTROLLER_PATH"
    exit 1
fi

# Check cluster connection
print_info "Checking cluster connection..."
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    echo "Please ensure your cluster is running and kubeconfig is properly configured"
    exit 1
fi
print_success "Cluster connected"
echo ""

# Deploy Notebook Controller using standalone overlay
print_info "Deploying Notebook Controller..."
echo "This will install:"
echo "  - Notebook CRD"
echo "  - RBAC (Roles, RoleBindings)"
echo "  - Controller Deployment"
echo "  - Service"
echo ""

cd "$NOTEBOOK_CONTROLLER_PATH"

# Use standalone overlay (không cần Istio, không cần Kubeflow)
print_info "Building manifests with standalone overlay..."
kustomize build overlays/standalone | kubectl apply -f -

print_success "Manifests applied"
echo ""

# Wait for CRD to be ready
print_info "Waiting for Notebook CRD to be ready..."
kubectl wait --for condition=established --timeout=60s crd/notebooks.kubeflow.org 2>/dev/null || true
print_success "Notebook CRD ready"
echo ""

# Wait for controller to be ready
print_info "Waiting for Notebook Controller to be ready..."
kubectl wait --for=condition=ready pod -l app=notebook-controller --timeout=180s -n notebook-controller-system 2>/dev/null || true
print_success "Notebook Controller ready"
echo ""

cd - > /dev/null

# Verify deployment
print_info "Verifying deployment..."
CONTROLLER_READY=$(kubectl get pods -n notebook-controller-system -l app=notebook-controller --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
CRD_EXISTS=$(kubectl get crd notebooks.kubeflow.org 2>/dev/null | wc -l)

if [ "$CONTROLLER_READY" -gt 0 ] && [ "$CRD_EXISTS" -gt 0 ]; then
    print_success "Notebook Controller deployed successfully! 🎉"
    echo ""
    echo "========================================"
    echo "Deployment Summary"
    echo "========================================"
    echo "Namespace: notebook-controller-system"
    echo "CRD: notebooks.kubeflow.org"
    echo ""
    echo "Controller Pods:"
    kubectl get pods -n notebook-controller-system
    echo ""
    echo "Next steps:"
    echo "  1. Create a Notebook: ./scripts/07_create_notebook.sh"
    echo "  2. Check status: kubectl get notebooks"
    echo "  3. Access notebook: ./scripts/08_access_notebook.sh"
    echo ""
else
    print_error "Deployment verification failed"
    echo "Controller ready: $CONTROLLER_READY"
    echo "CRD exists: $CRD_EXISTS"
    echo ""
    echo "Check logs:"
    echo "  kubectl logs -n notebook-controller-system -l app=notebook-controller"
    exit 1
fi

