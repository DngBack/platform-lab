#!/bin/bash

# Script: Cleanup Kubeflow
# Description: Remove Kubeflow installation

echo "========================================"
echo "Kubeflow Cleanup"
echo "========================================"
echo ""
echo "⚠️  WARNING: This will delete all Kubeflow resources!"
echo ""
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Cleanup cancelled"
    exit 0
fi

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() { echo -e "${YELLOW}➜ $1${NC}"; }
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }

MANIFESTS_DIR="./manifests"

if [ ! -d "$MANIFESTS_DIR" ]; then
    print_error "Manifests directory not found"
    echo "Falling back to manual cleanup..."
    
    # Manual cleanup
    print_info "Deleting Kubeflow namespaces..."
    kubectl delete namespace kubeflow --timeout=60s 2>/dev/null || kubectl delete namespace kubeflow --force --grace-period=0 2>/dev/null
    kubectl delete namespace kubeflow-user-example-com --timeout=60s 2>/dev/null || kubectl delete namespace kubeflow-user-example-com --force --grace-period=0 2>/dev/null
    kubectl delete namespace auth --timeout=60s 2>/dev/null || kubectl delete namespace auth --force --grace-period=0 2>/dev/null
    kubectl delete namespace knative-eventing --timeout=60s 2>/dev/null || kubectl delete namespace knative-eventing --force --grace-period=0 2>/dev/null
    kubectl delete namespace knative-serving --timeout=60s 2>/dev/null || kubectl delete namespace knative-serving --force --grace-period=0 2>/dev/null
    kubectl delete namespace istio-system --timeout=60s 2>/dev/null || kubectl delete namespace istio-system --force --grace-period=0 2>/dev/null
    kubectl delete namespace cert-manager --timeout=60s 2>/dev/null || kubectl delete namespace cert-manager --force --grace-period=0 2>/dev/null
    
else
    # Cleanup using manifests
    print_info "Cleaning up using manifests..."
    cd "$MANIFESTS_DIR"
    kustomize build example | kubectl delete -f - --timeout=60s 2>/dev/null || print_info "Some resources may have already been deleted"
    cd ..
fi

print_success "Namespaces deleted"
echo ""

# Ask if user wants to delete CRDs
read -p "Do you want to delete CRDs as well? (yes/no): " DELETE_CRDS

if [ "$DELETE_CRDS" = "yes" ]; then
    print_info "Deleting CRDs..."
    
    kubectl get crd | grep kubeflow | awk '{print $1}' | xargs kubectl delete crd 2>/dev/null || true
    kubectl get crd | grep istio | awk '{print $1}' | xargs kubectl delete crd 2>/dev/null || true
    kubectl get crd | grep knative | awk '{print $1}' | xargs kubectl delete crd 2>/dev/null || true
    kubectl get crd | grep cert-manager | awk '{print $1}' | xargs kubectl delete crd 2>/dev/null || true
    
    print_success "CRDs deleted"
fi

echo ""

# Verify cleanup
print_info "Verifying cleanup..."
REMAINING=$(kubectl get pods -A 2>/dev/null | grep -E 'kubeflow|istio|knative|cert-manager|auth' | wc -l)

if [ "$REMAINING" -eq 0 ]; then
    print_success "Cleanup completed successfully! ✨"
else
    print_error "Some pods are still running ($REMAINING pods)"
    echo "They will be terminated shortly. You can check with:"
    echo "  kubectl get pods -A | grep -E 'kubeflow|istio|knative'"
fi

echo ""
echo "Cleanup completed!"
echo ""
