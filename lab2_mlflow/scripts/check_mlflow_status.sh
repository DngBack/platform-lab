#!/bin/bash

# Check MLflow Server status

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info "Checking MLflow Server status..."
echo ""

# Check namespace
if kubectl get namespace mlflow &> /dev/null; then
    print_success "Namespace 'mlflow' exists"
else
    print_error "Namespace 'mlflow' not found"
    exit 1
fi

echo ""
print_info "Pods:"
kubectl get pods -n mlflow

echo ""
print_info "Services:"
kubectl get svc -n mlflow

echo ""
print_info "PVC:"
kubectl get pvc -n mlflow

echo ""
print_info "MLflow Server Logs (last 10 lines):"
POD_NAME=$(kubectl get pods -n mlflow -l app=mlflow-server -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$POD_NAME" ]; then
    kubectl logs -n mlflow "$POD_NAME" --tail=10
else
    print_error "MLflow pod not found"
fi

echo ""
print_info "To port-forward MLflow UI:"
echo "  kubectl port-forward -n mlflow svc/mlflow-service 5000:5000"




