#!/bin/bash

# Script: Setup GPU Support for Minikube
# Description: Cấu hình GPU support cho minikube cluster

set -e

echo "========================================"
echo "Setup GPU Support for Minikube"
echo "========================================"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_info() { echo -e "${YELLOW}➜ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_header() { echo -e "${BLUE}=== $1 ===${NC}"; }

# Check if nvidia-smi is available
print_header "Checking GPU Availability"
if ! command -v nvidia-smi &> /dev/null; then
    print_error "nvidia-smi not found!"
    echo "Please install NVIDIA drivers first."
    exit 1
fi

nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
print_success "GPU detected"
echo ""

# Check minikube status
print_header "Checking Minikube Status"
if ! minikube status &> /dev/null; then
    print_error "Minikube is not running"
    exit 1
fi

MINIKUBE_DRIVER=$(minikube config get driver 2>/dev/null || echo "unknown")
print_info "Current minikube driver: $MINIKUBE_DRIVER"
echo ""

# Check if GPU is already available in cluster
print_header "Checking Cluster GPU Support"
if kubectl get nodes -o jsonpath='{.items[*].status.capacity}' | grep -q "nvidia.com/gpu"; then
    print_success "GPU support is already configured!"
    kubectl get nodes -o jsonpath='{.items[*].status.capacity.nvidia\.com/gpu}' && echo ""
    exit 0
fi

print_info "GPU support not detected in cluster"
echo ""

# Check if NVIDIA device plugin is installed
print_header "Checking NVIDIA Device Plugin"
if kubectl get daemonset -n kube-system nvidia-device-plugin-daemonset &> /dev/null; then
    print_success "NVIDIA device plugin is installed"
else
    print_info "NVIDIA device plugin is not installed"
    echo ""
    read -p "Do you want to install NVIDIA device plugin? (y/n): " INSTALL_PLUGIN
    if [[ "$INSTALL_PLUGIN" =~ ^[Yy]$ ]]; then
        print_info "Installing NVIDIA device plugin..."
        kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.14.1/nvidia-device-plugin.yml
        print_success "NVIDIA device plugin installed"
        echo ""
        print_info "Waiting for device plugin to be ready..."
        kubectl wait --for=condition=ready pod -l name=nvidia-device-plugin-ds -n kube-system --timeout=120s || true
    fi
fi
echo ""

# Check minikube driver
print_header "Minikube GPU Configuration"
if [ "$MINIKUBE_DRIVER" != "none" ] && [ "$MINIKUBE_DRIVER" != "docker" ]; then
    print_error "Minikube driver '$MINIKUBE_DRIVER' may not support GPU passthrough"
    echo ""
    echo "For GPU support, minikube should use one of these drivers:"
    echo "  - none (bare metal)"
    echo "  - docker (with GPU support)"
    echo ""
    read -p "Do you want to restart minikube with GPU support? (y/n): " RESTART_MINIKUBE
    if [[ "$RESTART_MINIKUBE" =~ ^[Yy]$ ]]; then
        print_info "Stopping minikube..."
        minikube stop
        
        print_info "Starting minikube with GPU support..."
        echo ""
        echo "Note: This requires minikube to be run with appropriate flags."
        echo "For 'none' driver (bare metal):"
        echo "  minikube start --driver=none"
        echo ""
        echo "For 'docker' driver:"
        echo "  minikube start --driver=docker --gpus=all"
        echo ""
        read -p "Choose driver (none/docker): " DRIVER_CHOICE
        
        if [ "$DRIVER_CHOICE" = "none" ]; then
            minikube start --driver=none
        elif [ "$DRIVER_CHOICE" = "docker" ]; then
            minikube start --driver=docker --gpus=all
        else
            print_error "Invalid choice"
            exit 1
        fi
        
        print_success "Minikube restarted with GPU support"
    fi
else
    print_info "Minikube driver '$MINIKUBE_DRIVER' should support GPU"
    echo ""
    print_info "If GPU is still not detected, you may need to:"
    echo "  1. Restart minikube: minikube stop && minikube start"
    echo "  2. Ensure NVIDIA drivers are installed on the host"
    echo "  3. Install NVIDIA device plugin (if not already installed)"
fi
echo ""

# Final check
print_header "Final GPU Check"
sleep 5
if kubectl get nodes -o jsonpath='{.items[*].status.capacity}' | grep -q "nvidia.com/gpu"; then
    print_success "GPU support is now configured! 🎉"
    echo ""
    print_info "GPU resources available:"
    kubectl get nodes -o jsonpath='{.items[*].status.capacity.nvidia\.com/gpu}' && echo ""
else
    print_error "GPU support is still not detected"
    echo ""
    
    # Check if using docker driver
    CURRENT_DRIVER=$(minikube config get driver 2>/dev/null || echo "docker")
    if [ "$CURRENT_DRIVER" = "docker" ]; then
        print_error "⚠️  IMPORTANT: Minikube with 'docker' driver has limited GPU support!"
        echo ""
        echo "Minikube docker driver cannot directly access host GPU."
        echo "The device plugin cannot find NVML library inside the container."
        echo ""
        echo "Solutions:"
        echo ""
        echo "Option 1: Use driver 'none' (bare metal) - REQUIRES ROOT:"
        echo "  sudo minikube stop"
        echo "  sudo minikube start --driver=none"
        echo "  # Then reinstall device plugin"
        echo ""
        echo "Option 2: Create GPU notebook WITHOUT GPU requirement (for testing):"
        echo "  ./scripts/07_create_notebook.sh"
        echo "  # Choose option 3, then answer 'y' when asked"
        echo ""
        echo "Option 3: Use a production Kubernetes cluster with GPU nodes"
        echo "  (e.g., GKE, EKS, AKS with GPU node pools)"
        echo ""
    else
        echo "Troubleshooting steps:"
        echo "  1. Check NVIDIA device plugin: kubectl get pods -n kube-system | grep nvidia"
        echo "  2. Check device plugin logs: kubectl logs -n kube-system -l name=nvidia-device-plugin-ds"
        echo "  3. Check node capacity: kubectl describe node minikube | grep -i gpu"
        echo "  4. Restart minikube: minikube stop && minikube start --driver=none"
        echo "  5. Check NVIDIA drivers: nvidia-smi"
        echo "  6. Ensure NVIDIA Container Toolkit is installed on host"
    fi
fi
echo ""

