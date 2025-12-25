#!/bin/bash

# Script: Deploy Kubeflow
# Description: Deploy full Kubeflow installation using manifests

set -e

echo "========================================"
echo "Deploying Kubeflow"
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
KUBEFLOW_VERSION="v1.8.0"

# 1. Clone Kubeflow manifests
if [ -d "$MANIFESTS_DIR" ]; then
    print_info "Manifests directory already exists"
    read -p "Do you want to re-clone? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$MANIFESTS_DIR"
    fi
fi

if [ ! -d "$MANIFESTS_DIR" ]; then
    print_info "Cloning Kubeflow manifests..."
    git clone https://github.com/kubeflow/manifests.git "$MANIFESTS_DIR"
    cd "$MANIFESTS_DIR"
    git checkout "$KUBEFLOW_VERSION"
    cd ..
    print_success "Manifests cloned successfully"
fi
echo ""

# 2. Choose installation method
echo "Choose installation method:"
echo "1. Quick install (all components at once) - Faster but less control"
echo "2. Step-by-step install (component by component) - Slower but educational"
while true; do
    read -p "Enter choice (1 or 2): " INSTALL_METHOD
    INSTALL_METHOD=$(echo "$INSTALL_METHOD" | tr -d '[:space:]')  # Trim whitespace
    if [ "$INSTALL_METHOD" = "1" ] || [ "$INSTALL_METHOD" = "2" ]; then
        break
    else
        print_error "Invalid choice. Please enter 1 or 2."
    fi
done
echo ""

cd "$MANIFESTS_DIR"

if [ "$INSTALL_METHOD" = "1" ]; then
    # Quick installation
    print_info "Starting quick installation..."
    print_info "This will take 10-15 minutes. Please be patient..."
    echo ""
    
    # Apply manifests with retry
    while ! kustomize build example | kubectl apply -f -; do
        print_info "Retrying to apply resources..."
        sleep 10
    done
    
    print_success "Kubeflow deployed successfully!"
    
elif [ "$INSTALL_METHOD" = "2" ]; then
    # Step-by-step installation
    print_info "Starting step-by-step installation..."
    echo ""
    
    # 1. Cert Manager
    print_info "1/18: Deploying Cert Manager..."
    kustomize build common/cert-manager/cert-manager/base | kubectl apply -f -
    kubectl wait --for=condition=ready pod -l 'app in (cert-manager,webhook)' --timeout=180s -n cert-manager 2>/dev/null || true
    print_success "Cert Manager deployed"
    echo ""
    
    # 2. Istio CRDs
    print_info "2/18: Deploying Istio CRDs..."
    kustomize build common/istio-1-17/istio-crds/base | kubectl apply -f -
    print_success "Istio CRDs deployed"
    echo ""
    
    # 3. Istio Namespace
    print_info "3/18: Deploying Istio Namespace..."
    kustomize build common/istio-1-17/istio-namespace/base | kubectl apply -f -
    print_success "Istio Namespace deployed"
    echo ""
    
    # 4. Istio Install
    print_info "4/18: Deploying Istio..."
    kustomize build common/istio-1-17/istio-install/base | kubectl apply -f -
    sleep 30  # Wait for Istio to initialize
    print_success "Istio deployed"
    echo ""
    
    # 5. Dex
    print_info "5/18: Deploying Dex (Authentication)..."
    kustomize build common/dex/overlays/istio | kubectl apply -f -
    print_success "Dex deployed"
    echo ""
    
    # 6. OIDC AuthService
    print_info "6/18: Deploying OIDC AuthService..."
    kustomize build common/oidc-client/oidc-authservice/base | kubectl apply -f -
    print_success "OIDC AuthService deployed"
    echo ""
    
    # 7. Knative Serving
    print_info "7/18: Deploying Knative Serving..."
    kustomize build common/knative/knative-serving/overlays/gateways | kubectl apply -f -
    print_success "Knative Serving deployed"
    echo ""
    
    # 8. Knative Eventing
    print_info "8/18: Deploying Knative Eventing..."
    kustomize build common/knative/knative-eventing/base | kubectl apply -f -
    print_success "Knative Eventing deployed"
    echo ""
    
    # 9. Kubeflow Namespace
    print_info "9/18: Deploying Kubeflow Namespace..."
    kustomize build common/kubeflow-namespace/base | kubectl apply -f -
    print_success "Kubeflow Namespace deployed"
    echo ""
    
    # 10. Kubeflow Roles
    print_info "10/18: Deploying Kubeflow Roles..."
    kustomize build common/kubeflow-roles/base | kubectl apply -f -
    print_success "Kubeflow Roles deployed"
    echo ""
    
    # 11. Kubeflow Pipelines
    print_info "11/18: Deploying Kubeflow Pipelines..."
    kustomize build apps/pipeline/upstream/env/cert-manager/platform-agnostic-multi-user | kubectl apply -f -
    print_success "Kubeflow Pipelines deployed"
    echo ""
    
    # 12. KServe
    print_info "12/18: Deploying KServe..."
    kustomize build contrib/kserve/kserve | kubectl apply -f -
    print_success "KServe deployed"
    echo ""
    
    # 13. Katib
    print_info "13/18: Deploying Katib..."
    kustomize build apps/katib/upstream/installs/katib-with-kubeflow | kubectl apply -f -
    print_success "Katib deployed"
    echo ""
    
    # 14. Central Dashboard
    print_info "14/18: Deploying Central Dashboard..."
    kustomize build apps/centraldashboard/upstream/overlays/kserve | kubectl apply -f -
    print_success "Central Dashboard deployed"
    echo ""
    
    # 15. Admission Webhook
    print_info "15/18: Deploying Admission Webhook..."
    kustomize build apps/admission-webhook/upstream/overlays/cert-manager | kubectl apply -f -
    print_success "Admission Webhook deployed"
    echo ""
    
    # 16. Notebook Controller (Important!)
    print_info "16/18: Deploying Notebook Controller..."
    kustomize build apps/jupyter/notebook-controller/upstream/overlays/kubeflow | kubectl apply -f -
    print_success "Notebook Controller deployed"
    echo ""
    
    # 17. Jupyter Web App
    print_info "17/18: Deploying Jupyter Web App..."
    kustomize build apps/jupyter/jupyter-web-app/upstream/overlays/istio | kubectl apply -f -
    print_success "Jupyter Web App deployed"
    echo ""
    
    # 18. Additional components
    print_info "18/18: Deploying additional components..."
    kustomize build apps/profiles/upstream/overlays/kubeflow | kubectl apply -f -
    kustomize build apps/volumes-web-app/upstream/overlays/istio | kubectl apply -f -
    kustomize build apps/tensorboard/tensorboards-web-app/upstream/overlays/istio | kubectl apply -f -
    kustomize build apps/tensorboard/tensorboard-controller/upstream/overlays/kubeflow | kubectl apply -f -
    kustomize build apps/training-operator/upstream/overlays/kubeflow | kubectl apply -f -
    kustomize build common/user-namespace/base | kubectl apply -f -
    print_success "Additional components deployed"
    echo ""
    
else
    print_error "Invalid choice"
    exit 1
fi

cd ..

echo ""
print_success "Kubeflow deployment initiated!"
echo ""
echo "========================================"
echo "Next Steps:"
echo "========================================"
echo "1. Wait for all pods to be running (10-15 minutes):"
echo "   ./scripts/03_check_status.sh"
echo ""
echo "2. Access the dashboard:"
echo "   ./scripts/04_access_dashboard.sh"
echo ""
echo "Default credentials:"
echo "   Email: user@example.com"
echo "   Password: 12341234"
echo ""
