#!/bin/bash

# Script: Install Prerequisites for Kubeflow
# Description: Cài đặt các công cụ cần thiết để deploy Kubeflow

set -e

echo "========================================"
echo "Installing Kubeflow Prerequisites"
echo "========================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}➜ $1${NC}"
}

# 1. Check kubectl
echo "1. Checking kubectl..."
if command -v kubectl &> /dev/null; then
    KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null || kubectl version --client 2>/dev/null | grep "Client Version")
    print_success "kubectl already installed: $KUBECTL_VERSION"
else
    print_info "Installing kubectl..."
    
    # Download kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    
    # Make it executable
    chmod +x kubectl
    
    # Move to /usr/local/bin
    sudo mv kubectl /usr/local/bin/
    
    print_success "kubectl installed successfully"
fi
echo ""

# 2. Check Kubernetes cluster connection
echo "2. Checking Kubernetes cluster connection..."
if kubectl cluster-info &> /dev/null; then
    print_success "Connected to Kubernetes cluster"
    kubectl cluster-info
else
    print_error "Cannot connect to Kubernetes cluster"
    echo "Please ensure your cluster is running and kubeconfig is properly configured"
    exit 1
fi
echo ""

# 3. Check kustomize
echo "3. Checking kustomize..."
if command -v kustomize &> /dev/null; then
    KUSTOMIZE_VERSION=$(kustomize version --short 2>/dev/null || kustomize version 2>/dev/null)
    print_success "kustomize already installed: $KUSTOMIZE_VERSION"
else
    print_info "Installing kustomize..."
    
    # Install kustomize
    curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
    
    # Move to /usr/local/bin
    sudo mv kustomize /usr/local/bin/
    
    print_success "kustomize installed successfully"
fi
echo ""

# 4. Check jq (useful for JSON parsing)
echo "4. Checking jq..."
if command -v jq &> /dev/null; then
    print_success "jq already installed"
else
    print_info "Installing jq..."
    sudo apt-get update -qq
    sudo apt-get install -y jq
    print_success "jq installed successfully"
fi
echo ""

# 5. Check cluster resources
echo "5. Checking cluster resources..."
print_info "Nodes:"
kubectl get nodes -o wide
echo ""

print_info "Storage Classes:"
kubectl get storageclass
echo ""

# Check if metrics-server is installed
if kubectl get deployment metrics-server -n kube-system &> /dev/null; then
    print_success "Metrics server is installed"
    echo "Resource usage:"
    kubectl top nodes 2>/dev/null || echo "Metrics not available yet, please wait..."
else
    print_info "Metrics server not found (optional, but recommended)"
fi
echo ""

# 6. Check minimum requirements
echo "6. Checking minimum requirements..."

# Get total CPU and Memory
TOTAL_CPU=$(kubectl get nodes -o json | jq '[.items[].status.capacity.cpu | tonumber] | add')
TOTAL_MEM_KB=$(kubectl get nodes -o json | jq '[.items[].status.capacity.memory | gsub("Ki"; "") | tonumber] | add')
TOTAL_MEM_GB=$(echo "scale=2; $TOTAL_MEM_KB / 1024 / 1024" | bc)

echo "Cluster Resources:"
echo "  Total CPU: ${TOTAL_CPU} cores"
echo "  Total Memory: ${TOTAL_MEM_GB} GB"
echo ""

# Check if meets minimum requirements
if (( $(echo "$TOTAL_CPU >= 4" | bc -l) )); then
    print_success "CPU requirement met (>= 4 cores)"
else
    print_error "CPU requirement NOT met (need >= 4 cores, have $TOTAL_CPU)"
fi

if (( $(echo "$TOTAL_MEM_GB >= 12" | bc -l) )); then
    print_success "Memory requirement met (>= 12 GB)"
else
    print_error "Memory requirement NOT met (need >= 12 GB, have ${TOTAL_MEM_GB} GB)"
fi
echo ""

# 7. Summary
echo "========================================"
echo "Prerequisites Check Summary"
echo "========================================"
print_success "kubectl: Installed"
print_success "kustomize: Installed"
print_success "jq: Installed"
print_success "Kubernetes cluster: Connected"
echo ""
echo "You are ready to deploy Kubeflow!"
echo "Next step: Run ./02_deploy_kubeflow.sh"
echo ""
