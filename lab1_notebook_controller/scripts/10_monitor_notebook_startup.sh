#!/bin/bash

# Script: Monitor Notebook Startup Progress
# Description: Monitor notebook pod startup progress với chi tiết

set -e

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

# Get notebook name and namespace
if [ -z "$1" ] || [ -z "$2" ]; then
    read -p "Enter notebook name: " NOTEBOOK_NAME
    read -p "Enter namespace (default: default): " NOTEBOOK_NAMESPACE
    NOTEBOOK_NAMESPACE=${NOTEBOOK_NAMESPACE:-default}
else
    NOTEBOOK_NAME=$1
    NOTEBOOK_NAMESPACE=$2
fi

echo ""
print_header "Monitoring Notebook: $NOTEBOOK_NAME"
echo "Namespace: $NOTEBOOK_NAMESPACE"
echo ""

# Get pod name
POD_NAME=$(kubectl get pods -n "$NOTEBOOK_NAMESPACE" -l notebook-name="$NOTEBOOK_NAME" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -z "$POD_NAME" ]; then
    print_error "Pod not found for notebook '$NOTEBOOK_NAME'"
    exit 1
fi

print_info "Pod: $POD_NAME"
echo ""

# Monitor loop
START_TIME=$(date +%s)
LAST_STATUS=""
LAST_EVENT=""

while true; do
    # Get current status
    STATUS=$(kubectl get pod "$POD_NAME" -n "$NOTEBOOK_NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    READY=$(kubectl get pod "$POD_NAME" -n "$NOTEBOOK_NAMESPACE" -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null || echo "false")
    CONTAINER_STATE=$(kubectl get pod "$POD_NAME" -n "$NOTEBOOK_NAMESPACE" -o jsonpath='{.status.containerStatuses[0].state}' 2>/dev/null || echo "{}")
    
    # Calculate elapsed time
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
    ELAPSED_MIN=$((ELAPSED / 60))
    ELAPSED_SEC=$((ELAPSED % 60))
    
    # Get latest event
    LATEST_EVENT=$(kubectl get events -n "$NOTEBOOK_NAMESPACE" --field-selector involvedObject.name="$POD_NAME" --sort-by='.lastTimestamp' 2>/dev/null | tail -1 | awk '{print $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15}')
    
    # Clear line and print status
    printf "\r\033[K"
    printf "⏱️  Elapsed: %dm %ds | Status: %s | Ready: %s" "$ELAPSED_MIN" "$ELAPSED_SEC" "$STATUS" "$READY"
    
    # Print event if changed
    if [ "$LATEST_EVENT" != "$LAST_EVENT" ] && [ -n "$LATEST_EVENT" ]; then
        echo ""
        echo "📢 Event: $LATEST_EVENT"
        LAST_EVENT="$LATEST_EVENT"
    fi
    
    # Check if ready
    if [ "$READY" = "true" ]; then
        echo ""
        echo ""
        print_success "Notebook is ready! 🎉"
        echo ""
        print_header "Final Status"
        kubectl get pod "$POD_NAME" -n "$NOTEBOOK_NAMESPACE"
        echo ""
        print_info "Total startup time: ${ELAPSED_MIN}m ${ELAPSED_SEC}s"
        break
    fi
    
    # Check for errors
    if [ "$STATUS" = "Failed" ] || [ "$STATUS" = "Error" ]; then
        echo ""
        echo ""
        print_error "Pod failed to start!"
        echo ""
        print_header "Error Details"
        kubectl describe pod "$POD_NAME" -n "$NOTEBOOK_NAMESPACE" | tail -20
        exit 1
    fi
    
    # Check for timeout (30 minutes)
    if [ $ELAPSED -gt 1800 ]; then
        echo ""
        echo ""
        print_error "Timeout after 30 minutes!"
        echo ""
        print_header "Current Status"
        kubectl describe pod "$POD_NAME" -n "$NOTEBOOK_NAMESPACE" | tail -30
        exit 1
    fi
    
    sleep 5
done

echo ""
print_info "You can now access the notebook:"
echo "  ./scripts/08_access_notebook.sh $NOTEBOOK_NAME $NOTEBOOK_NAMESPACE"
echo ""








