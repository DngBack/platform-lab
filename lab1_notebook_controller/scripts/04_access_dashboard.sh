#!/bin/bash

# Script: Access Kubeflow Dashboard
# Description: Setup access to Kubeflow dashboard

echo "========================================"
echo "Kubeflow Dashboard Access"
echo "========================================"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${YELLOW}➜ $1${NC}"; }
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_header() { echo -e "${BLUE}=== $1 ===${NC}"; }

# Check if istio-ingressgateway exists
if ! kubectl get svc istio-ingressgateway -n istio-system &> /dev/null; then
    echo "Error: istio-ingressgateway service not found"
    echo "Please ensure Kubeflow is deployed correctly"
    exit 1
fi

echo "Choose access method:"
echo ""
echo "1. Port Forward (Recommended for local testing)"
echo "   - Simple and quick"
echo "   - Access via localhost"
echo "   - Good for development"
echo ""
echo "2. NodePort (For external access)"
echo "   - Access from other machines"
echo "   - Uses node IP and port"
echo "   - Good for shared clusters"
echo ""
echo "3. LoadBalancer (For cloud providers)"
echo "   - Automatic external IP"
echo "   - Production-ready"
echo "   - Requires cloud provider support"
echo ""
read -p "Enter choice (1-3): " ACCESS_METHOD
echo ""

case $ACCESS_METHOD in
    1)
        # Port Forward
        print_header "Setting up Port Forward"
        echo ""
        print_info "Starting port-forward on port 8080..."
        print_info "Dashboard will be available at: http://localhost:8080"
        echo ""
        print_success "Press Ctrl+C to stop port-forwarding"
        echo ""
        echo "Default credentials:"
        echo "  Email: user@example.com"
        echo "  Password: 12341234"
        echo ""
        
        # Run port-forward
        kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80 --address 0.0.0.0
        ;;
        
    2)
        # NodePort
        print_header "Setting up NodePort"
        echo ""
        print_info "Patching service to use NodePort..."
        
        kubectl patch svc istio-ingressgateway -n istio-system -p '{"spec":{"type":"NodePort"}}'
        
        # Get NodePort
        NODE_PORT=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
        
        # Get Node IP (first node)
        NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
        
        echo ""
        print_success "NodePort configured!"
        echo ""
        echo "Access the dashboard at:"
        echo "  http://$NODE_IP:$NODE_PORT"
        echo ""
        echo "To get all node IPs:"
        echo "  kubectl get nodes -o wide"
        echo ""
        echo "Default credentials:"
        echo "  Email: user@example.com"
        echo "  Password: 12341234"
        echo ""
        ;;
        
    3)
        # LoadBalancer
        print_header "Setting up LoadBalancer"
        echo ""
        print_info "Patching service to use LoadBalancer..."
        
        kubectl patch svc istio-ingressgateway -n istio-system -p '{"spec":{"type":"LoadBalancer"}}'
        
        echo ""
        print_info "Waiting for external IP (this may take a few minutes)..."
        echo ""
        
        # Wait for external IP
        EXTERNAL_IP=""
        while [ -z "$EXTERNAL_IP" ]; do
            echo "Waiting for external IP..."
            EXTERNAL_IP=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
            if [ -z "$EXTERNAL_IP" ]; then
                EXTERNAL_IP=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
            fi
            [ -z "$EXTERNAL_IP" ] && sleep 5
        done
        
        echo ""
        print_success "LoadBalancer configured!"
        echo ""
        echo "Access the dashboard at:"
        echo "  http://$EXTERNAL_IP"
        echo ""
        echo "Default credentials:"
        echo "  Email: user@example.com"
        echo "  Password: 12341234"
        echo ""
        ;;
        
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac
