#!/bin/bash

# Cleanup MLflow deployment

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_warning "This will delete all MLflow resources including data!"
read -p "Are you sure? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    print_info "Cleanup cancelled"
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="$SCRIPT_DIR/../manifests"

print_info "Deleting MLflow resources..."

# Delete in reverse order
kubectl delete -f "$MANIFESTS_DIR/mlflow-service.yaml" --ignore-not-found=true
kubectl delete -f "$MANIFESTS_DIR/mlflow-deployment.yaml" --ignore-not-found=true

# Ask about PVC deletion
read -p "Delete PVC (this will delete all MLflow data)? (yes/no): " delete_pvc
if [ "$delete_pvc" = "yes" ]; then
    kubectl delete -f "$MANIFESTS_DIR/pvc.yaml" --ignore-not-found=true
    print_success "PVC deleted"
else
    print_info "PVC preserved (data is safe)"
fi

# Delete namespace (will delete all resources)
read -p "Delete namespace 'mlflow'? (yes/no): " delete_ns
if [ "$delete_ns" = "yes" ]; then
    kubectl delete namespace mlflow --ignore-not-found=true
    print_success "Namespace deleted"
else
    print_info "Namespace preserved"
fi

print_success "Cleanup complete!"



