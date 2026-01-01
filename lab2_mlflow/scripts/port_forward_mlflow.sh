#!/bin/bash

# Port-forward MLflow UI to local machine

set -e

PORT=${1:-5000}

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_info "Starting port-forward for MLflow Server..."
print_info "Local port: $PORT"
print_info "Remote: mlflow-service.mlflow.svc.cluster.local:5000"
echo ""
print_info "Access MLflow UI at: http://localhost:$PORT"
echo ""
print_info "Press Ctrl+C to stop port-forwarding"
echo ""

kubectl port-forward -n mlflow svc/mlflow-service "$PORT:5000"

