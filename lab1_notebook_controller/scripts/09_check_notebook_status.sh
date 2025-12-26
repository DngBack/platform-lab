#!/bin/bash

# Script: Check Notebook Status
# Description: Kiểm tra trạng thái của Notebooks

set -e

echo "========================================"
echo "Notebook Status Check"
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

# Check if Notebook CRD exists
if ! kubectl get crd notebooks.kubeflow.org &> /dev/null; then
    print_error "Notebook CRD not found!"
    echo "Please deploy Notebook Controller first:"
    echo "  ./scripts/06_deploy_notebook_controller.sh"
    exit 1
fi

# Get all notebooks
print_header "All Notebooks"
NOTEBOOKS=$(kubectl get notebooks -A --no-headers 2>/dev/null)

if [ -z "$NOTEBOOKS" ]; then
    print_info "No notebooks found"
    echo ""
    echo "Create a notebook:"
    echo "  ./scripts/07_create_notebook.sh"
    exit 0
fi

kubectl get notebooks -A
echo ""

# Detailed status for each notebook
print_header "Detailed Status"
echo ""

while IFS= read -r line; do
    if [ -z "$line" ]; then
        continue
    fi
    
    NAMESPACE=$(echo "$line" | awk '{print $1}')
    NAME=$(echo "$line" | awk '{print $2}')
    READY=$(echo "$line" | awk '{print $3}')
    AGE=$(echo "$line" | awk '{print $4}')
    
    echo "----------------------------------------"
    echo "Notebook: $NAME (namespace: $NAMESPACE)"
    echo "----------------------------------------"
    echo "Ready: $READY"
    echo "Age: $AGE"
    echo ""
    
    # Get pod status
    POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l notebook-name="$NAME" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -n "$POD_NAME" ]; then
        echo "Pod: $POD_NAME"
        POD_STATUS=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
        echo "Pod Status: $POD_STATUS"
        
        # Get resource usage if metrics available
        if kubectl top pod "$POD_NAME" -n "$NAMESPACE" &> /dev/null; then
            echo "Resource Usage:"
            kubectl top pod "$POD_NAME" -n "$NAMESPACE"
        fi
    else
        print_error "No pod found for this notebook"
    fi
    
    echo ""
    
    # Get events
    echo "Recent Events:"
    kubectl get events -n "$NAMESPACE" --field-selector involvedObject.name="$NAME" --sort-by='.lastTimestamp' | tail -3
    echo ""
    
done <<< "$NOTEBOOKS"

# Summary
print_header "Summary"
TOTAL=$(echo "$NOTEBOOKS" | wc -l)
READY_COUNT=$(echo "$NOTEBOOKS" | grep -c "True" || echo "0")

echo "Total Notebooks: $TOTAL"
echo "Ready: $READY_COUNT"
echo "Not Ready: $((TOTAL - READY_COUNT))"
echo ""

if [ "$READY_COUNT" -eq "$TOTAL" ] && [ "$TOTAL" -gt 0 ]; then
    print_success "All notebooks are ready! 🎉"
else
    print_info "Some notebooks are not ready yet"
    echo "Wait a few minutes and run this script again"
fi

echo ""
echo "To access a notebook:"
echo "  ./scripts/08_access_notebook.sh <notebook-name> <namespace>"
echo ""


