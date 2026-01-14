#!/bin/bash

# Lab 2: Deploy MLflow Server on Kubernetes
# This script deploys MLflow Tracking Server with persistent storage

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed. Please install kubectl first."
    exit 1
fi

# Check cluster connection
print_info "Checking cluster connection..."
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
    exit 1
fi
print_success "Cluster connection OK"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="$SCRIPT_DIR/../manifests"

# Deploy namespace
print_info "Creating namespace 'mlflow'..."
kubectl apply -f "$MANIFESTS_DIR/namespace.yaml"
print_success "Namespace created"

# Wait for namespace
sleep 2

# Create PVC
print_info "Creating PersistentVolumeClaim for MLflow storage..."
kubectl apply -f "$MANIFESTS_DIR/pvc.yaml"
print_success "PVC created"

# Wait for PVC to be bound
print_info "Waiting for PVC to be bound..."
for i in {1..30}; do
    STATUS=$(kubectl get pvc mlflow-pvc -n mlflow -o jsonpath='{.status.phase}' 2>/dev/null || echo "Pending")
    if [ "$STATUS" = "Bound" ]; then
        print_success "PVC is bound"
        break
    fi
    if [ $i -eq 30 ]; then
        print_warning "PVC is not bound yet. This might be OK if StorageClass is not available."
        print_info "You can check PVC status with: kubectl get pvc -n mlflow"
    else
        echo -n "."
        sleep 2
    fi
done
echo ""

# Deploy MLflow server
print_info "Deploying MLflow Server..."
kubectl apply -f "$MANIFESTS_DIR/mlflow-deployment.yaml"
print_success "MLflow Deployment created"

# Create Service
print_info "Creating MLflow Service..."
kubectl apply -f "$MANIFESTS_DIR/mlflow-service.yaml"
print_success "MLflow Service created"

# Wait for deployment to be ready
print_info "Waiting for MLflow Server to be ready (this may take 1-2 minutes)..."
echo ""

if kubectl wait --for=condition=available --timeout=180s deployment/mlflow-server -n mlflow 2>/dev/null; then
    print_success "MLflow Server is ready! 🎉"
else
    print_warning "Deployment might still be starting. Check status with: kubectl get pods -n mlflow"
fi

echo ""
print_info "Getting MLflow Server status..."
kubectl get pods -n mlflow
kubectl get svc -n mlflow

echo ""
print_success "=========================================="
print_success "MLflow Server Deployment Complete!"
print_success "=========================================="
echo ""
print_info "MLflow Server Information:"
echo "  - Namespace: mlflow"
echo "  - Service: mlflow-service.mlflow.svc.cluster.local:5000"
echo "  - Internal URL: http://mlflow-service.mlflow.svc.cluster.local:5000"
echo ""
print_info "To access MLflow UI from your local machine:"
echo "  1. Port-forward: kubectl port-forward -n mlflow svc/mlflow-service 5000:5000"
echo "  2. Open browser: http://localhost:5000"
echo ""
print_info "To connect from a notebook, use:"
echo "  mlflow.set_tracking_uri('http://mlflow-service.mlflow.svc.cluster.local:5000')"
echo ""



