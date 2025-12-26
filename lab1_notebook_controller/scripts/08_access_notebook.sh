#!/bin/bash

# Script: Access Notebook
# Description: Setup port-forward để truy cập Notebook

set -e

echo "========================================"
echo "Access Notebook"
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

# Check cluster connection
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

# List available notebooks
print_header "Available Notebooks"
NOTEBOOKS=$(kubectl get notebooks -A --no-headers 2>/dev/null | awk '{print $2 " -n " $1}')

if [ -z "$NOTEBOOKS" ]; then
    print_error "No notebooks found!"
    echo "Please create a notebook first:"
    echo "  ./scripts/07_create_notebook.sh"
    exit 1
fi

# Display notebooks
echo "Found notebooks:"
kubectl get notebooks -A
echo ""

# Get notebook name and namespace
if [ -z "$1" ] || [ -z "$2" ]; then
    read -p "Enter notebook name: " NOTEBOOK_NAME
    read -p "Enter namespace (default: default): " NOTEBOOK_NAMESPACE
    NOTEBOOK_NAMESPACE=${NOTEBOOK_NAMESPACE:-default}
else
    NOTEBOOK_NAME=$1
    NOTEBOOK_NAMESPACE=$2
fi

# Verify notebook exists
if ! kubectl get notebook "$NOTEBOOK_NAME" -n "$NOTEBOOK_NAMESPACE" &> /dev/null; then
    print_error "Notebook '$NOTEBOOK_NAME' not found in namespace '$NOTEBOOK_NAMESPACE'"
    echo ""
    echo "Available notebooks:"
    kubectl get notebooks -A
    exit 1
fi

# Check if notebook is ready
# Notebook status uses conditions, not a simple ready field
READY=$(kubectl get notebook "$NOTEBOOK_NAME" -n "$NOTEBOOK_NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")

# Fallback: If notebook status not available, check pod status directly
if [ "$READY" != "True" ]; then
    # Check if pod is running as fallback
    POD_READY=$(kubectl get pods -n "$NOTEBOOK_NAMESPACE" -l notebook-name="$NOTEBOOK_NAME" -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null || echo "false")
    POD_PHASE=$(kubectl get pods -n "$NOTEBOOK_NAMESPACE" -l notebook-name="$NOTEBOOK_NAME" -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Unknown")
    
    # If pod is running and ready, proceed anyway
    if [ "$POD_READY" = "true" ] && [ "$POD_PHASE" = "Running" ]; then
        print_info "Notebook status not fully updated, but pod is ready. Proceeding..."
        echo ""
    else
        print_error "Notebook is not ready yet!"
        echo ""
        echo "Current status:"
        kubectl get notebook "$NOTEBOOK_NAME" -n "$NOTEBOOK_NAMESPACE"
        echo ""
        echo "Check pod status:"
        kubectl get pods -n "$NOTEBOOK_NAMESPACE" -l notebook-name="$NOTEBOOK_NAME"
        echo ""
        echo "Wait for notebook to be ready, then try again."
        exit 1
    fi
fi

# Get pod name
POD_NAME=$(kubectl get pods -n "$NOTEBOOK_NAMESPACE" -l notebook-name="$NOTEBOOK_NAME" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$POD_NAME" ]; then
    print_error "Pod not found for notebook '$NOTEBOOK_NAME'"
    exit 1
fi

# Get port (default Jupyter port is 8888)
PORT=${3:-8888}

print_header "Setting up Port Forward"
echo ""
print_info "Notebook: $NOTEBOOK_NAME"
print_info "Namespace: $NOTEBOOK_NAMESPACE"
print_info "Pod: $POD_NAME"
print_info "Port: $PORT"
echo ""

# Build notebook URL path (JupyterLab uses path-based routing)
NOTEBOOK_PATH="/notebook/$NOTEBOOK_NAMESPACE/$NOTEBOOK_NAME/lab"
NOTEBOOK_URL="http://localhost:$PORT$NOTEBOOK_PATH"

# Try to get token from various sources
print_info "Getting access token..."
TOKEN=""

# Method 1: Try jupyter notebook list (older Jupyter)
TOKEN=$(kubectl exec -n "$NOTEBOOK_NAMESPACE" "$POD_NAME" -- jupyter notebook list 2>/dev/null | grep -oP 'token=\K[^\s]+' | head -1 || echo "")

# Method 2: Try jupyter server list (newer JupyterLab)
if [ -z "$TOKEN" ]; then
    TOKEN=$(kubectl exec -n "$NOTEBOOK_NAMESPACE" "$POD_NAME" -- jupyter server list 2>/dev/null | grep -oP 'token=\K[^\s]+' | head -1 || echo "")
fi

# Method 3: Extract from logs (look for token in startup logs)
if [ -z "$TOKEN" ]; then
    TOKEN=$(kubectl logs -n "$NOTEBOOK_NAMESPACE" "$POD_NAME" 2>&1 | grep -oP 'token[=:]\s*\K[^\s,]+' | head -1 || echo "")
fi

# Display access information
echo ""
echo "========================================"
echo "Access Information"
echo "========================================"
echo "Notebook URL: $NOTEBOOK_URL"

if [ -n "$TOKEN" ]; then
    print_success "Token found!"
    echo "Token: $TOKEN"
    echo ""
    echo "Full URL with token: $NOTEBOOK_URL?token=$TOKEN"
    echo ""
    echo "Or access directly and enter token when prompted"
else
    print_info "Token not automatically found"
    echo ""
    echo "📝 To get token manually, check pod logs:"
    echo "   kubectl logs -n $NOTEBOOK_NAMESPACE $POD_NAME | grep -i token"
    echo ""
    echo "Or try accessing the URL - JupyterLab may prompt for token from logs"
    echo ""
    echo "⚠️  Note: You may not need token if you're authenticated via kubectl"
fi

echo ""
echo "========================================"
echo "Port Forward Started"
echo "========================================"
echo ""
print_success "Notebook is accessible at: $NOTEBOOK_URL"
echo ""
print_info "Press Ctrl+C to stop port-forwarding"
echo ""
print_info "If you see 404 error, make sure to use the full path:"
echo "   $NOTEBOOK_URL"
echo ""

# Start port-forward
kubectl port-forward -n "$NOTEBOOK_NAMESPACE" "$POD_NAME" "$PORT:8888"


