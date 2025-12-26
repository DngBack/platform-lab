#!/bin/bash

# Script: Create Notebook from YAML
# Description: Tạo Notebook resource từ YAML file

set -e

echo "========================================"
echo "Create Notebook"
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

# Check if Notebook CRD exists
if ! kubectl get crd notebooks.kubeflow.org &> /dev/null; then
    print_error "Notebook CRD not found!"
    echo "Please deploy Notebook Controller first:"
    echo "  ./scripts/06_deploy_notebook_controller.sh"
    exit 1
fi

# Check cluster connection
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

# Get namespace (default to default)
read -p "Enter namespace for notebook (default: default): " NOTEBOOK_NAMESPACE
NOTEBOOK_NAMESPACE=${NOTEBOOK_NAMESPACE:-default}

# Create namespace if it doesn't exist
if ! kubectl get namespace "$NOTEBOOK_NAMESPACE" &> /dev/null; then
    print_info "Creating namespace: $NOTEBOOK_NAMESPACE"
    kubectl create namespace "$NOTEBOOK_NAMESPACE"
    print_success "Namespace created"
    echo ""
fi

# Choose notebook type
print_header "Choose Notebook Type"
echo "1. Basic Jupyter (CPU only)"
echo "2. Jupyter with TensorFlow (CPU)"
echo "3. Jupyter with TensorFlow (GPU - requires GPU nodes)"
echo "4. Custom YAML file"
echo ""
read -p "Enter choice (1-4): " NOTEBOOK_TYPE

case $NOTEBOOK_TYPE in
    1)
        NOTEBOOK_NAME="basic-notebook"
        NOTEBOOK_IMAGE="kubeflownotebookswg/jupyter-scipy:latest"
        CPU="1.0"
        MEMORY="2Gi"
        ;;
    2)
        NOTEBOOK_NAME="tensorflow-notebook"
        NOTEBOOK_IMAGE="kubeflownotebookswg/jupyter-tensorflow-full:latest"
        CPU="2.0"
        MEMORY="4Gi"
        ;;
    3)
        NOTEBOOK_NAME="gpu-notebook"
        NOTEBOOK_IMAGE="kubeflownotebookswg/jupyter-tensorflow-cuda-full:latest"
        CPU="2.0"
        MEMORY="4Gi"
        GPU="1"
        
        # Check if cluster has GPU support
        if ! kubectl get nodes -o jsonpath='{.items[*].status.capacity}' | grep -q "nvidia.com/gpu"; then
            print_error "Cluster does not have GPU support!"
            echo ""
            echo "Your cluster nodes do not report GPU resources (nvidia.com/gpu)."
            echo "This usually means:"
            echo "  1. NVIDIA device plugin is not installed"
            echo "  2. Minikube is not configured with GPU support"
            echo ""
            read -p "Do you want to create GPU notebook WITHOUT GPU requirement? (y/n): " CREATE_WITHOUT_GPU
            if [[ "$CREATE_WITHOUT_GPU" =~ ^[Yy]$ ]]; then
                print_info "Creating GPU notebook without GPU requirement (for testing)..."
                GPU=""  # Remove GPU requirement
            else
                print_error "Cannot create GPU notebook. Please configure GPU support first."
                echo ""
                echo "To configure GPU support for minikube, see:"
                echo "  ./scripts/11_setup_gpu_support.sh (if available)"
                echo ""
                echo "Or manually:"
                echo "  1. Install NVIDIA device plugin:"
                echo "     kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.14.1/nvidia-device-plugin.yml"
                echo "  2. Restart minikube with GPU:"
                echo "     minikube stop"
                echo "     minikube start --driver=none --gpus=all"
                exit 1
            fi
        fi
        ;;
    4)
        read -p "Enter path to YAML file: " YAML_FILE
        if [ ! -f "$YAML_FILE" ]; then
            print_error "File not found: $YAML_FILE"
            exit 1
        fi
        print_info "Applying custom YAML: $YAML_FILE"
        kubectl apply -f "$YAML_FILE" -n "$NOTEBOOK_NAMESPACE"
        print_success "Notebook created from custom YAML"
        echo ""
        echo "Check status: kubectl get notebooks -n $NOTEBOOK_NAMESPACE"
        exit 0
        ;;
    *)
        print_error "Invalid choice"
        exit 1
        ;;
esac

# Create temporary YAML file
TEMP_YAML=$(mktemp)

if [ "$NOTEBOOK_TYPE" = "3" ]; then
    # GPU notebook
    if [ -n "$GPU" ]; then
        # With GPU requirement
        cat > "$TEMP_YAML" <<EOF
apiVersion: kubeflow.org/v1
kind: Notebook
metadata:
  name: $NOTEBOOK_NAME
  namespace: $NOTEBOOK_NAMESPACE
spec:
  template:
    spec:
      containers:
      - name: $NOTEBOOK_NAME
        image: $NOTEBOOK_IMAGE
        env:
        - name: NVIDIA_VISIBLE_DEVICES
          value: "all"
        resources:
          requests:
            cpu: ${CPU}
            memory: ${MEMORY}
            nvidia.com/gpu: ${GPU}
          limits:
            cpu: ${CPU}
            memory: ${MEMORY}
            nvidia.com/gpu: ${GPU}
      volumes:
      - name: workspace
        persistentVolumeClaim:
          claimName: ${NOTEBOOK_NAME}-workspace
EOF
    else
        # Without GPU requirement (for testing)
        cat > "$TEMP_YAML" <<EOF
apiVersion: kubeflow.org/v1
kind: Notebook
metadata:
  name: $NOTEBOOK_NAME
  namespace: $NOTEBOOK_NAMESPACE
spec:
  template:
    spec:
      containers:
      - name: $NOTEBOOK_NAME
        image: $NOTEBOOK_IMAGE
        env:
        - name: NVIDIA_VISIBLE_DEVICES
          value: "all"
        resources:
          requests:
            cpu: ${CPU}
            memory: ${MEMORY}
          limits:
            cpu: ${CPU}
            memory: ${MEMORY}
      volumes:
      - name: workspace
        persistentVolumeClaim:
          claimName: ${NOTEBOOK_NAME}-workspace
EOF
    fi
else
    # CPU notebook
    cat > "$TEMP_YAML" <<EOF
apiVersion: kubeflow.org/v1
kind: Notebook
metadata:
  name: $NOTEBOOK_NAME
  namespace: $NOTEBOOK_NAMESPACE
spec:
  template:
    spec:
      containers:
      - name: $NOTEBOOK_NAME
        image: $NOTEBOOK_IMAGE
        resources:
          requests:
            cpu: ${CPU}
            memory: ${MEMORY}
          limits:
            cpu: ${CPU}
            memory: ${MEMORY}
      volumes:
      - name: workspace
        persistentVolumeClaim:
          claimName: ${NOTEBOOK_NAME}-workspace
EOF
fi

# Create PVC for workspace
print_info "Creating PVC for workspace..."
cat > "${TEMP_YAML}.pvc" <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${NOTEBOOK_NAME}-workspace
  namespace: $NOTEBOOK_NAMESPACE
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
EOF

kubectl apply -f "${TEMP_YAML}.pvc"
print_success "PVC created"
echo ""

# Apply notebook
print_info "Creating Notebook: $NOTEBOOK_NAME"
kubectl apply -f "$TEMP_YAML"
print_success "Notebook created"
echo ""

# Cleanup temp files
rm -f "$TEMP_YAML" "${TEMP_YAML}.pvc"

# Wait for notebook to be ready
print_info "Waiting for Notebook to be ready (this may take a few minutes)..."
echo ""

# Check notebook status
for i in {1..30}; do
    STATUS=$(kubectl get notebook "$NOTEBOOK_NAME" -n "$NOTEBOOK_NAMESPACE" -o jsonpath='{.status.ready}' 2>/dev/null || echo "false")
    if [ "$STATUS" = "true" ]; then
        print_success "Notebook is ready! 🎉"
        break
    fi
    echo -n "."
    sleep 5
done
echo ""

# Show notebook status
print_header "Notebook Status"
kubectl get notebook "$NOTEBOOK_NAME" -n "$NOTEBOOK_NAMESPACE"
echo ""

# Show pod status
print_header "Pod Status"
kubectl get pods -n "$NOTEBOOK_NAMESPACE" -l notebook-name="$NOTEBOOK_NAME"
echo ""

print_success "Notebook created successfully!"
echo ""
echo "Next steps:"
echo "  1. Access notebook: ./scripts/08_access_notebook.sh"
echo "  2. Check logs: kubectl logs -n $NOTEBOOK_NAMESPACE -l notebook-name=$NOTEBOOK_NAME"
echo "  3. Describe notebook: kubectl describe notebook $NOTEBOOK_NAME -n $NOTEBOOK_NAMESPACE"
echo ""

