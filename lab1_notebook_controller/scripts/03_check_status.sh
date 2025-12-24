#!/bin/bash

# Script: Check Kubeflow Status
# Description: Monitor Kubeflow deployment status

echo "========================================"
echo "Checking Kubeflow Status"
echo "========================================"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() { echo -e "${BLUE}=== $1 ===${NC}"; }
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }

# Function to check pods in namespace
check_namespace() {
    local ns=$1
    local name=$2
    
    print_header "$name ($ns)"
    
    if ! kubectl get namespace "$ns" &> /dev/null; then
        print_error "Namespace $ns does not exist"
        echo ""
        return
    fi
    
    local total=$(kubectl get pods -n "$ns" 2>/dev/null | grep -v NAME | wc -l)
    local running=$(kubectl get pods -n "$ns" 2>/dev/null | grep Running | wc -l)
    local pending=$(kubectl get pods -n "$ns" 2>/dev/null | grep Pending | wc -l)
    local error=$(kubectl get pods -n "$ns" 2>/dev/null | grep -E 'Error|CrashLoopBackOff|ImagePullBackOff' | wc -l)
    
    echo "Pods: $running/$total running"
    
    if [ "$error" -gt 0 ]; then
        print_error "$error pods in error state"
        kubectl get pods -n "$ns" | grep -E 'Error|CrashLoopBackOff|ImagePullBackOff'
    fi
    
    if [ "$pending" -gt 0 ]; then
        print_warning "$pending pods pending"
    fi
    
    if [ "$running" -eq "$total" ] && [ "$total" -gt 0 ]; then
        print_success "All pods running!"
    fi
    
    echo ""
}

# Check all Kubeflow namespaces
check_namespace "cert-manager" "Certificate Manager"
check_namespace "istio-system" "Istio Service Mesh"
check_namespace "auth" "Authentication (Dex)"
check_namespace "knative-eventing" "Knative Eventing"
check_namespace "knative-serving" "Knative Serving"
check_namespace "kubeflow" "Kubeflow Core"
check_namespace "kubeflow-user-example-com" "Kubeflow User Namespace"

# Check CRDs
print_header "Custom Resource Definitions"
echo "Notebook CRDs:"
kubectl get crd | grep notebook || print_error "No notebook CRDs found"
echo ""

# Check important services
print_header "Important Services"
echo "Istio Ingress Gateway:"
kubectl get svc -n istio-system istio-ingressgateway 2>/dev/null || print_error "Istio ingress not found"
echo ""

# Check notebooks
print_header "Notebooks"
kubectl get notebooks -A 2>/dev/null || echo "No notebooks created yet"
echo ""

# Overall summary
print_header "Overall Summary"

TOTAL_PODS=$(kubectl get pods -A 2>/dev/null | grep -E 'kubeflow|istio-system|knative|cert-manager|auth' | wc -l)
RUNNING_PODS=$(kubectl get pods -A 2>/dev/null | grep -E 'kubeflow|istio-system|knative|cert-manager|auth' | grep Running | wc -l)
ERROR_PODS=$(kubectl get pods -A 2>/dev/null | grep -E 'kubeflow|istio-system|knative|cert-manager|auth' | grep -E 'Error|CrashLoopBackOff|ImagePullBackOff' | wc -l)

echo "Total Kubeflow pods: $TOTAL_PODS"
echo "Running: $RUNNING_PODS"
echo "Errors: $ERROR_PODS"

PERCENTAGE=0
if [ "$TOTAL_PODS" -gt 0 ]; then
    PERCENTAGE=$((RUNNING_PODS * 100 / TOTAL_PODS))
fi

echo "Progress: $PERCENTAGE%"
echo ""

if [ "$PERCENTAGE" -eq 100 ]; then
    print_success "Kubeflow is fully deployed! 🎉"
    echo ""
    echo "You can now access the dashboard:"
    echo "  ./scripts/04_access_dashboard.sh"
elif [ "$PERCENTAGE" -gt 80 ]; then
    print_warning "Kubeflow is almost ready. Please wait a few more minutes."
    echo "Run this script again to check progress."
elif [ "$ERROR_PODS" -gt 0 ]; then
    print_error "Some pods are in error state. Please check logs:"
    echo "  kubectl logs <pod-name> -n <namespace>"
else
    print_warning "Deployment in progress ($PERCENTAGE% complete)"
    echo "This may take 10-15 minutes. Please wait..."
    echo "Run this script again to check progress."
fi

echo ""
echo "To watch pods in real-time:"
echo "  watch -n 2 'kubectl get pods -A | grep -E \"kubeflow|istio|knative\"'"
echo ""
