# Task 1: Deploy and Test Full Kubeflow - Hướng Dẫn Chi Tiết

## Tổng Quan
Task này giúp bạn:
- Hiểu cách deploy một hệ thống ML platform hoàn chỉnh
- Làm quen với các components của Kubeflow
- Biết cách sử dụng Kubeflow Notebooks để chạy ML workloads

---

## Phần 1: Kiến Thức Cơ Bản

### Kubeflow là gì?
Kubeflow là một nền tảng ML/AI mã nguồn mở chạy trên Kubernetes, bao gồm:
- **Notebooks**: Jupyter notebooks để phát triển và thử nghiệm
- **Pipelines**: Orchestrate ML workflows
- **Training Operators**: Train models với TensorFlow, PyTorch, XGBoost, etc.
- **Serving**: Deploy models để inference
- **AutoML**: Katib cho hyperparameter tuning
- **Multi-tenancy**: Quản lý users và namespaces

### Kiến trúc Kubeflow
```
┌─────────────────────────────────────────────────┐
│           Kubeflow Dashboard (UI)               │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│  Central Dashboard + Auth (Dex/OIDC)           │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│  Kubeflow Components                            │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐       │
│  │Notebooks │ │Pipelines │ │Training  │       │
│  │Controller│ │          │ │Operators │       │
│  └──────────┘ └──────────┘ └──────────┘       │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│         Kubernetes Cluster                      │
│  (Pods, Services, Volumes, etc.)               │
└─────────────────────────────────────────────────┘
```

---

## Phần 2: Prerequisites

### Yêu cầu hệ thống tối thiểu:
- **Kubernetes cluster**: v1.25+
- **RAM**: Tối thiểu 12GB (khuyến nghị 16GB+)
- **CPU**: Tối thiểu 4 cores (khuyến nghị 8 cores+)
- **Storage**: Tối thiểu 50GB
- **kubectl**: Đã cài đặt và configured
- **kustomize**: v5.0+ (Kubeflow sử dụng kustomize để deploy)

### Kiểm tra cluster của bạn:
```bash
# Kiểm tra nodes
kubectl get nodes

# Kiểm tra resource available
kubectl top nodes  # Cần metrics-server

# Kiểm tra storage classes
kubectl get storageclass
```

---

## Phần 3: Installation Methods

Có 3 cách chính để deploy Kubeflow:

### Method 1: Kubeflow Manifests (Recommended cho học tập)
**Ưu điểm**: 
- Hiểu rõ từng component
- Dễ customize
- Official method

**Nhược điểm**:
- Phức tạp hơn
- Cần hiểu về kustomize

### Method 2: MiniKF (Nhanh nhất)
**Ưu điểm**:
- Deploy trong vài phút
- All-in-one package
- Tốt cho development/testing

**Nhược điểm**:
- Ít customize
- Cần Vagrant + VirtualBox

### Method 3: Managed Services
- Google Cloud AI Platform
- AWS Sagemaker với Kubeflow
- Azure ML

---

## Phần 4: Deploy Kubeflow (Method 1 - Manifests)

### Bước 1: Cài đặt Kustomize

```bash
# Download kustomize
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash

# Move to PATH
sudo mv kustomize /usr/local/bin/

# Verify
kustomize version
```

### Bước 2: Clone Kubeflow Manifests

```bash
# Clone repository
cd ~/platform-lab/lab1_notebook_controller
git clone https://github.com/kubeflow/manifests.git
cd manifests

# Checkout stable version (v1.8.0 là stable hiện tại)
git checkout v1.8.0
```

### Bước 3: Deploy Kubeflow

```bash
# Deploy tất cả components
# Chú ý: Quá trình này sẽ mất 10-15 phút

# Option 1: Deploy tất cả (full installation)
while ! kustomize build example | kubectl apply -f -; do echo "Retrying to apply resources"; sleep 10; done

# Option 2: Deploy từng component (để hiểu rõ hơn)
# 1. Cert Manager
kustomize build common/cert-manager/cert-manager/base | kubectl apply -f -
kubectl wait --for=condition=ready pod -l 'app in (cert-manager,webhook)' --timeout=180s -n cert-manager

# 2. Istio
kustomize build common/istio-1-17/istio-crds/base | kubectl apply -f -
kustomize build common/istio-1-17/istio-namespace/base | kubectl apply -f -
kustomize build common/istio-1-17/istio-install/base | kubectl apply -f -

# 3. Dex (Authentication)
kustomize build common/dex/overlays/istio | kubectl apply -f -

# 4. OIDC AuthService
kustomize build common/oidc-client/oidc-authservice/base | kubectl apply -f -

# 5. Knative
kustomize build common/knative/knative-serving/overlays/gateways | kubectl apply -f -
kustomize build common/knative/knative-eventing/base | kubectl apply -f -

# 6. Kubeflow Namespace
kustomize build common/kubeflow-namespace/base | kubectl apply -f -

# 7. Kubeflow Roles
kustomize build common/kubeflow-roles/base | kubectl apply -f -

# 8. Kubeflow Pipelines
kustomize build apps/pipeline/upstream/env/cert-manager/platform-agnostic-multi-user | kubectl apply -f -

# 9. KServe
kustomize build contrib/kserve/kserve | kubectl apply -f -

# 10. Katib
kustomize build apps/katib/upstream/installs/katib-with-kubeflow | kubectl apply -f -

# 11. Central Dashboard
kustomize build apps/centraldashboard/upstream/overlays/kserve | kubectl apply -f -

# 12. Admission Webhook
kustomize build apps/admission-webhook/upstream/overlays/cert-manager | kubectl apply -f -

# 13. Notebook Controller (Component chính cho lab này!)
kustomize build apps/jupyter/notebook-controller/upstream/overlays/kubeflow | kubectl apply -f -

# 14. Jupyter Web App
kustomize build apps/jupyter/jupyter-web-app/upstream/overlays/istio | kubectl apply -f -

# 15. Profiles + KFAM
kustomize build apps/profiles/upstream/overlays/kubeflow | kubectl apply -f -

# 16. Volumes Web App
kustomize build apps/volumes-web-app/upstream/overlays/istio | kubectl apply -f -

# 17. Tensorboards
kustomize build apps/tensorboard/tensorboards-web-app/upstream/overlays/istio | kubectl apply -f -
kustomize build apps/tensorboard/tensorboard-controller/upstream/overlays/kubeflow | kubectl apply -f -

# 18. Training Operators
kustomize build apps/training-operator/upstream/overlays/kubeflow | kubectl apply -f -

# 19. User Namespace
kustomize build common/user-namespace/base | kubectl apply -f -
```

### Bước 4: Verify Installation

```bash
# Kiểm tra tất cả pods
kubectl get pods -A | grep -E 'kubeflow|istio-system|knative|cert-manager'

# Kiểm tra namespaces
kubectl get namespaces

# Đợi tất cả pods running (có thể mất 10-15 phút)
# Chú ý các namespaces:
# - istio-system
# - auth
# - cert-manager
# - kubeflow
# - kubeflow-user-example-com

# Kiểm tra chi tiết từng namespace
kubectl get pods -n kubeflow
kubectl get pods -n istio-system
kubectl get pods -n auth
kubectl get pods -n cert-manager

# Tất cả pods phải ở trạng thái Running hoặc Completed
```

---

## Phần 5: Access Kubeflow Dashboard

### Option 1: Port Forward (Đơn giản nhất)

```bash
# Port forward Istio ingress gateway
kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80

# Truy cập: http://localhost:8080
```

### Option 2: NodePort (Cho external access)

```bash
# Patch service để dùng NodePort
kubectl patch svc istio-ingressgateway -n istio-system -p '{"spec":{"type":"NodePort"}}'

# Lấy NodePort
kubectl get svc istio-ingressgateway -n istio-system

# Lấy Node IP
kubectl get nodes -o wide

# Truy cập: http://<NODE_IP>:<NODE_PORT>
```

### Option 3: LoadBalancer (Nếu cluster hỗ trợ)

```bash
# Patch service để dùng LoadBalancer
kubectl patch svc istio-ingressgateway -n istio-system -p '{"spec":{"type":"LoadBalancer"}}'

# Đợi external IP
kubectl get svc istio-ingressgateway -n istio-system -w
```

### Default Login Credentials:
- **Email**: `user@example.com`
- **Password**: `12341234`

> **Lưu ý**: Đây là credentials mặc định cho demo. Trong production cần configure authentication provider thực tế.

---

## Phần 6: Create and Test Notebook

### Bước 1: Access Kubeflow UI
1. Mở browser và truy cập dashboard
2. Login với credentials trên
3. Chọn namespace: `kubeflow-user-example-com`

### Bước 2: Create Notebook

1. Click **"Notebooks"** trong left sidebar
2. Click **"+ New Notebook"**
3. Configure:
   - **Name**: `my-first-notebook`
   - **Image**: Chọn `jupyter-tensorflow-full` (hoặc `jupyter-pytorch-full`)
   - **CPU**: 1.0
   - **Memory**: 2.0Gi
   - **Workspace Volume**: 
     - Type: New
     - Size: 5Gi
   - **Data Volumes**: Skip (không cần cho test cơ bản)
4. Click **"Launch"**

### Bước 3: Wait for Notebook Ready

```bash
# Kiểm tra notebook pod
kubectl get pods -n kubeflow-user-example-com

# Xem logs nếu có issue
kubectl logs -n kubeflow-user-example-com <notebook-pod-name>

# Describe pod để troubleshoot
kubectl describe pod -n kubeflow-user-example-com <notebook-pod-name>
```

### Bước 4: Connect to Notebook

1. Trong UI, đợi status chuyển sang **"Running"** (màu xanh)
2. Click **"Connect"**
3. Jupyter interface sẽ mở trong tab mới

---

## Phần 7: Test CPU Workload

### Test 1: Basic Python & Libraries

Tạo notebook mới và chạy:

```python
# Cell 1: Check Python version
import sys
print(f"Python version: {sys.version}")

# Cell 2: Check installed libraries
import tensorflow as tf
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

print(f"TensorFlow version: {tf.__version__}")
print(f"NumPy version: {np.__version__}")
print(f"Pandas version: {pd.__version__}")

# Cell 3: Check CPU info
import multiprocessing
print(f"CPU cores available: {multiprocessing.cpu_count()}")
```

### Test 2: Simple ML Training (CPU)

```python
# Cell 1: Import libraries
import tensorflow as tf
from tensorflow import keras
import numpy as np
import time

# Cell 2: Load dataset
print("Loading MNIST dataset...")
(x_train, y_train), (x_test, y_test) = keras.datasets.mnist.load_data()

# Normalize
x_train = x_train.astype('float32') / 255
x_test = x_test.astype('float32') / 255

print(f"Training samples: {x_train.shape[0]}")
print(f"Test samples: {x_test.shape[0]}")

# Cell 3: Build model
model = keras.Sequential([
    keras.layers.Flatten(input_shape=(28, 28)),
    keras.layers.Dense(128, activation='relu'),
    keras.layers.Dropout(0.2),
    keras.layers.Dense(10, activation='softmax')
])

model.compile(
    optimizer='adam',
    loss='sparse_categorical_crossentropy',
    metrics=['accuracy']
)

model.summary()

# Cell 4: Train model
print("Training model on CPU...")
start_time = time.time()

history = model.fit(
    x_train, y_train,
    epochs=5,
    batch_size=128,
    validation_split=0.1,
    verbose=1
)

training_time = time.time() - start_time
print(f"\nTraining completed in {training_time:.2f} seconds")

# Cell 5: Evaluate
test_loss, test_acc = model.evaluate(x_test, y_test, verbose=0)
print(f"\nTest accuracy: {test_acc:.4f}")
print(f"Test loss: {test_loss:.4f}")

# Cell 6: Plot training history
import matplotlib.pyplot as plt

plt.figure(figsize=(12, 4))

plt.subplot(1, 2, 1)
plt.plot(history.history['accuracy'], label='Training Accuracy')
plt.plot(history.history['val_accuracy'], label='Validation Accuracy')
plt.title('Model Accuracy')
plt.xlabel('Epoch')
plt.ylabel('Accuracy')
plt.legend()
plt.grid(True)

plt.subplot(1, 2, 2)
plt.plot(history.history['loss'], label='Training Loss')
plt.plot(history.history['val_loss'], label='Validation Loss')
plt.title('Model Loss')
plt.xlabel('Epoch')
plt.ylabel('Loss')
plt.legend()
plt.grid(True)

plt.tight_layout()
plt.show()
```

### Test 3: CPU Intensive Task

```python
# Cell 1: CPU benchmark
import numpy as np
import time

def cpu_intensive_task(size=5000):
    """Matrix multiplication benchmark"""
    print(f"Running matrix multiplication ({size}x{size})...")
    start = time.time()
    
    A = np.random.rand(size, size)
    B = np.random.rand(size, size)
    C = np.dot(A, B)
    
    elapsed = time.time() - start
    print(f"Completed in {elapsed:.2f} seconds")
    return elapsed

# Cell 2: Run benchmark
times = []
sizes = [1000, 2000, 3000, 4000, 5000]

for size in sizes:
    t = cpu_intensive_task(size)
    times.append(t)

# Cell 3: Plot results
import matplotlib.pyplot as plt

plt.figure(figsize=(10, 6))
plt.plot(sizes, times, marker='o', linewidth=2, markersize=8)
plt.title('CPU Performance: Matrix Multiplication', fontsize=14)
plt.xlabel('Matrix Size', fontsize=12)
plt.ylabel('Time (seconds)', fontsize=12)
plt.grid(True, alpha=0.3)
plt.tight_layout()
plt.show()
```

---

## Phần 8: Test GPU Workload (Optional)

### Bước 1: Check GPU Availability

```bash
# Kiểm tra node có GPU không
kubectl get nodes -o json | jq '.items[].status.capacity'

# Hoặc
kubectl describe nodes | grep -A 5 "Capacity\|Allocatable" | grep gpu
```

### Bước 2: Create GPU Notebook

Nếu cluster có GPU:

1. Create new notebook
2. Trong configuration:
   - **Image**: `jupyter-tensorflow-cuda-full` hoặc `jupyter-pytorch-cuda-full`
   - **GPUs**: Chọn số lượng GPU (ví dụ: 1)
   - **GPU Vendor**: `nvidia.com/gpu`
3. Launch notebook

### Bước 3: Test GPU

```python
# Cell 1: Check GPU với TensorFlow
import tensorflow as tf

print("TensorFlow version:", tf.__version__)
print("GPU Available:", tf.config.list_physical_devices('GPU'))
print("CUDA Available:", tf.test.is_built_with_cuda())

# List all GPUs
gpus = tf.config.list_physical_devices('GPU')
if gpus:
    for gpu in gpus:
        print(f"GPU: {gpu}")
        details = tf.config.experimental.get_device_details(gpu)
        print(f"Details: {details}")
else:
    print("No GPU detected")

# Cell 2: GPU computation test
import time

# Create random tensors
with tf.device('/CPU:0'):
    cpu_a = tf.random.normal([10000, 10000])
    cpu_b = tf.random.normal([10000, 10000])

if gpus:
    with tf.device('/GPU:0'):
        gpu_a = tf.random.normal([10000, 10000])
        gpu_b = tf.random.normal([10000, 10000])

# CPU computation
start = time.time()
with tf.device('/CPU:0'):
    cpu_result = tf.matmul(cpu_a, cpu_b)
cpu_time = time.time() - start
print(f"CPU time: {cpu_time:.4f} seconds")

# GPU computation
if gpus:
    start = time.time()
    with tf.device('/GPU:0'):
        gpu_result = tf.matmul(gpu_a, gpu_b)
    gpu_time = time.time() - start
    print(f"GPU time: {gpu_time:.4f} seconds")
    print(f"Speedup: {cpu_time/gpu_time:.2f}x")
```

---

## Phần 9: Verify Deployment Health

### Check All Components

```bash
# Script để check tất cả components
cat > check_kubeflow.sh << 'EOF'
#!/bin/bash

echo "=== Checking Kubeflow Installation ==="
echo ""

echo "1. Namespaces:"
kubectl get ns | grep -E 'kubeflow|istio|knative|cert-manager|auth'
echo ""

echo "2. Pods in kubeflow namespace:"
kubectl get pods -n kubeflow
echo ""

echo "3. Pods in istio-system:"
kubectl get pods -n istio-system
echo ""

echo "4. Services in istio-system:"
kubectl get svc -n istio-system
echo ""

echo "5. Notebook CRDs:"
kubectl get crd | grep notebook
echo ""

echo "6. Check notebooks:"
kubectl get notebooks -A
echo ""

echo "7. PVCs:"
kubectl get pvc -A
echo ""

echo "=== Summary ==="
TOTAL_PODS=$(kubectl get pods -A | grep -E 'kubeflow|istio|knative|cert-manager|auth' | wc -l)
RUNNING_PODS=$(kubectl get pods -A | grep -E 'kubeflow|istio|knative|cert-manager|auth' | grep Running | wc -l)
echo "Total Kubeflow-related pods: $TOTAL_PODS"
echo "Running pods: $RUNNING_PODS"
EOF

chmod +x check_kubeflow.sh
./check_kubeflow.sh
```

---

## Phần 10: Troubleshooting

### Common Issues

#### 1. Pods không start (Pending/CrashLoopBackOff)

```bash
# Check pod status
kubectl get pods -n kubeflow

# Describe pod để xem events
kubectl describe pod <pod-name> -n kubeflow

# Check logs
kubectl logs <pod-name> -n kubeflow

# Check previous logs nếu pod restart
kubectl logs <pod-name> -n kubeflow --previous
```

**Nguyên nhân thường gặp**:
- Không đủ resources (CPU/Memory)
- Image pull error
- Volume mount issues
- Configuration errors

#### 2. Cannot access dashboard

```bash
# Check istio-ingressgateway
kubectl get svc -n istio-system istio-ingressgateway

# Check istio pods
kubectl get pods -n istio-system

# Check port-forward
kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80 --address 0.0.0.0
```

#### 3. Notebook cannot start

```bash
# Check notebook resource
kubectl get notebooks -n kubeflow-user-example-com

# Describe notebook
kubectl describe notebook <notebook-name> -n kubeflow-user-example-com

# Check notebook pod
kubectl get pods -n kubeflow-user-example-com

# Check PVC
kubectl get pvc -n kubeflow-user-example-com
```

#### 4. Out of Resources

```bash
# Check node resources
kubectl top nodes

# Check pod resources
kubectl top pods -A

# Free up resources:
# - Delete unused namespaces
# - Delete unused PVCs
# - Scale down deployments
```

### Useful Debug Commands

```bash
# Check all resources in namespace
kubectl get all -n kubeflow

# Check events in namespace
kubectl get events -n kubeflow --sort-by='.lastTimestamp'

# Check resource quotas
kubectl get resourcequotas -A

# Check limit ranges
kubectl get limitranges -A

# Force delete stuck resources
kubectl delete pod <pod-name> -n kubeflow --force --grace-period=0
```

---

## Phần 11: Clean Up (Chuẩn bị cho Task 2)

Sau khi hoàn thành testing, cleanup để chuẩn bị cho Task 2:

```bash
# Delete Kubeflow (cẩn thận!)
cd ~/platform-lab/lab1_notebook_controller/manifests

# Delete tất cả
kustomize build example | kubectl delete -f -

# Hoặc delete từng namespace
kubectl delete namespace kubeflow
kubectl delete namespace kubeflow-user-example-com
kubectl delete namespace istio-system
kubectl delete namespace knative-eventing
kubectl delete namespace knative-serving
kubectl delete namespace auth
kubectl delete namespace cert-manager

# Delete CRDs (optional - làm khi muốn cleanup hoàn toàn)
kubectl get crd | grep kubeflow | awk '{print $1}' | xargs kubectl delete crd
kubectl get crd | grep istio | awk '{print $1}' | xargs kubectl delete crd
kubectl get crd | grep knative | awk '{print $1}' | xargs kubectl delete crd

# Verify cleanup
kubectl get pods -A | grep -E 'kubeflow|istio|knative'
```

---

## Phần 12: Learning Outcomes

Sau khi hoàn thành Task 1, bạn sẽ hiểu:

✅ **Về Kubeflow**:
- Kubeflow architecture và components
- Cách deploy một ML platform phức tạp
- Cách các components tương tác với nhau

✅ **Về Kubernetes**:
- Custom Resource Definitions (CRDs)
- Operators và Controllers
- Multi-tenancy với namespaces
- Service mesh (Istio)
- Volume management

✅ **Về ML Workflows**:
- Cách setup development environment cho ML
- Cách chạy training jobs
- Resource management (CPU/GPU)

✅ **Troubleshooting Skills**:
- Debug Kubernetes applications
- Check logs và events
- Resource monitoring

---

## Next Steps

Sau Task 1, bạn sẽ:
1. Có hiểu biết toàn diện về Kubeflow
2. Biết cách operate một ML platform
3. Sẵn sàng cho **Task 2**: Deploy chỉ Notebook Controller
4. Hiểu sự khác biệt giữa full platform vs minimal deployment

---

## References

- [Kubeflow Official Docs](https://www.kubeflow.org/docs/)
- [Kubeflow Manifests GitHub](https://github.com/kubeflow/manifests)
- [Kubeflow Notebooks Documentation](https://www.kubeflow.org/docs/components/notebooks/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Istio Documentation](https://istio.io/latest/docs/)

---

**Good luck with Task 1! 🚀**
