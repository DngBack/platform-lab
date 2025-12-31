# Task 1: Deploy and Test Full Kubeflow

## 📋 Tổng Quan

Task này giúp bạn triển khai và test toàn bộ Kubeflow platform trên Kubernetes cluster. Bạn sẽ học cách:
- Deploy một ML platform hoàn chỉnh
- Tạo và quản lý Jupyter Notebooks
- Chạy ML workloads (CPU/GPU)
- Hiểu kiến trúc của Kubeflow

## 🎯 Mục Tiêu Học Tập

✅ Hiểu architecture của Kubeflow và các components  
✅ Biết cách deploy complex applications trên Kubernetes  
✅ Làm quen với Notebook Controller (chuẩn bị cho Task 2)  
✅ Thực hành ML workflows trong môi trường Kubernetes  

## 📁 Cấu Trúc Thư Mục

```
lab1_notebook_controller/
├── README.md                          # File này
├── TODO.md                            # Task list
├── task1_guide.md                     # Hướng dẫn chi tiết
├── scripts/                           # Scripts tự động
│   ├── 01_install_prerequisites.sh    # Cài đặt prerequisites
│   ├── 02_deploy_kubeflow.sh          # Deploy Kubeflow
│   ├── 03_check_status.sh             # Kiểm tra status
│   ├── 04_access_dashboard.sh         # Access dashboard
│   └── 05_cleanup.sh                  # Cleanup
├── examples/                          # Code examples
│   ├── basic_test.ipynb               # Basic Python test
│   ├── ml_training_cpu.ipynb          # CPU training example
│   └── ml_training_gpu.ipynb          # GPU training example (optional)
└── manifests/                         # Kubeflow manifests (sẽ clone)
```

## 🚀 Quick Start

### Bước 1: Cài Đặt Prerequisites

```bash
cd ~/platform-lab/lab1_notebook_controller
./scripts/01_install_prerequisites.sh
```

Script này sẽ:
- Cài đặt kubectl (nếu chưa có)
- Cài đặt kustomize
- Kiểm tra cluster connection
- Verify minimum requirements

### Bước 2: Deploy Kubeflow

```bash
./scripts/02_deploy_kubeflow.sh
```

Bạn sẽ được hỏi chọn installation method:
- **Option 1**: Quick install (nhanh, ít control)
- **Option 2**: Step-by-step (chậm hơn nhưng educational)

**Khuyến nghị**: Chọn Option 2 để hiểu từng component

⏱️ **Thời gian**: 10-15 phút

### Bước 3: Kiểm Tra Status

```bash
./scripts/03_check_status.sh
```

Chạy lệnh này định kỳ để theo dõi deployment progress. Khi tất cả pods Running, bạn có thể tiếp tục.

### Bước 4: Access Dashboard

```bash
./scripts/04_access_dashboard.sh
```

Chọn access method:
- **Port Forward**: Đơn giản nhất, cho local testing
- **NodePort**: Cho external access
- **LoadBalancer**: Cho production (cần cloud provider)

**Default credentials:**
- Email: `user@example.com`
- Password: `12341234`

## 📝 Thực Hành

### 1. Create Notebook

1. Mở Kubeflow Dashboard
2. Click **"Notebooks"** → **"+ New Notebook"**
3. Configure:
   - Name: `my-first-notebook`
   - Image: `jupyter-tensorflow-full`
   - CPU: 1.0
   - Memory: 2.0Gi
   - Workspace Volume: 5Gi
4. Click **"Launch"**
5. Đợi status = Running
6. Click **"Connect"**

### 2. Test CPU Workload

Copy các examples từ `examples/` hoặc tạo notebook mới:

**Test cơ bản:**
```python
import tensorflow as tf
import numpy as np

print(f"TensorFlow: {tf.__version__}")
print(f"NumPy: {np.__version__}")
```

**Train simple model:**
```python
# Load MNIST dataset
(x_train, y_train), (x_test, y_test) = tf.keras.datasets.mnist.load_data()

# Build model
model = tf.keras.Sequential([
    tf.keras.layers.Flatten(input_shape=(28, 28)),
    tf.keras.layers.Dense(128, activation='relu'),
    tf.keras.layers.Dense(10, activation='softmax')
])

model.compile(optimizer='adam',
              loss='sparse_categorical_crossentropy',
              metrics=['accuracy'])

# Train
model.fit(x_train/255.0, y_train, epochs=5, validation_split=0.1)

# Evaluate
test_loss, test_acc = model.evaluate(x_test/255.0, y_test)
print(f"Test accuracy: {test_acc}")
```

### 3. Test GPU Workload (Optional)

Nếu cluster có GPU:

1. Create notebook với GPU configuration
2. Select image: `jupyter-tensorflow-cuda-full`
3. Set GPUs: 1
4. Test GPU:

```python
import tensorflow as tf

print("GPU Available:", tf.config.list_physical_devices('GPU'))

# GPU vs CPU comparison
import time

# CPU
with tf.device('/CPU:0'):
    cpu_a = tf.random.normal([10000, 10000])
    cpu_b = tf.random.normal([10000, 10000])
    start = time.time()
    cpu_c = tf.matmul(cpu_a, cpu_b)
    cpu_time = time.time() - start

# GPU
with tf.device('/GPU:0'):
    gpu_a = tf.random.normal([10000, 10000])
    gpu_b = tf.random.normal([10000, 10000])
    start = time.time()
    gpu_c = tf.matmul(gpu_a, gpu_b)
    gpu_time = time.time() - start

print(f"CPU: {cpu_time:.4f}s")
print(f"GPU: {gpu_time:.4f}s")
print(f"Speedup: {cpu_time/gpu_time:.2f}x")
```

## 🔍 Kiểm Tra và Debug

### Xem tất cả pods

```bash
kubectl get pods -A | grep -E 'kubeflow|istio|knative'
```

### Xem logs của một pod

```bash
kubectl logs -n kubeflow <pod-name>
```

### Xem events trong namespace

```bash
kubectl get events -n kubeflow --sort-by='.lastTimestamp'
```

### Describe pod (troubleshooting)

```bash
kubectl describe pod -n kubeflow <pod-name>
```

### Xem notebook resources

```bash
kubectl get notebooks -A
kubectl describe notebook -n kubeflow-user-example-com <notebook-name>
```

## 🧹 Cleanup

Sau khi hoàn thành testing, cleanup để chuẩn bị Task 2:

```bash
./scripts/05_cleanup.sh
```

Script sẽ hỏi:
- Có chắc chắn muốn delete không?
- Có muốn delete CRDs không?

⚠️ **Lưu ý**: Backup data quan trọng trước khi cleanup!

## 📚 Tài Liệu Tham Khảo

- **Hướng dẫn chi tiết**: Đọc `task1_guide.md`
- **Kubeflow Docs**: https://www.kubeflow.org/docs/
- **Kubeflow Manifests**: https://github.com/kubeflow/manifests
- **Notebooks Guide**: https://www.kubeflow.org/docs/components/notebooks/

## ❓ Troubleshooting

### Pods không start

**Nguyên nhân**: Không đủ resources

**Giải pháp**:
```bash
# Check resources
kubectl top nodes

# Scale down deployments nếu cần
kubectl scale deployment -n kubeflow <deployment-name> --replicas=0
```

### Cannot access dashboard

**Nguyên nhân**: Istio ingress không ready

**Giải pháp**:
```bash
# Check istio-ingressgateway
kubectl get pods -n istio-system
kubectl get svc -n istio-system

# Restart port-forward
kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80
```

### Notebook stuck in pending

**Nguyên nhân**: PVC không được provision

**Giải pháp**:
```bash
# Check PVC
kubectl get pvc -n kubeflow-user-example-com

# Check storage class
kubectl get storageclass

# Describe PVC
kubectl describe pvc -n kubeflow-user-example-com <pvc-name>
```

## ✅ Checklist Hoàn Thành

- [ ] Prerequisites đã cài đặt
- [ ] Kubeflow deployed thành công
- [ ] Tất cả pods Running
- [ ] Dashboard accessible
- [ ] Notebook created và connected
- [ ] CPU workload test thành công
- [ ] GPU workload test (nếu có GPU)
- [ ] Hiểu kiến trúc Kubeflow
- [ ] Cleanup completed

## 🎓 Kiến Thức Đạt Được

Sau Task 1, bạn nên hiểu:

**1. Kubeflow Architecture**
- Components và vai trò của chúng
- Cách các components tương tác
- Multi-tenancy với profiles/namespaces

**2. Kubernetes Concepts**
- Custom Resource Definitions (CRDs)
- Operators và Controllers
- Service Mesh (Istio)
- Volume management

**3. ML Workflows**
- Setup Jupyter environments
- Resource allocation (CPU/GPU)
- Training models trong cluster

**4. Operations**
- Deploy complex applications
- Monitor và debug
- Resource management

## 🔜 Next: Task 2

Sau khi hoàn thành Task 1:
1. Cleanup Kubeflow (chạy script cleanup)
2. Đọc hướng dẫn Task 2
3. Deploy chỉ Notebook Controller
4. So sánh với full Kubeflow

**Điểm khác biệt chính**:
- Task 1: Full platform với tất cả components
- Task 2: Minimal deployment, chỉ Notebook Controller
- Học được: Microservices architecture, component independence

---

**Questions?** Tham khảo `task1_guide.md` để biết chi tiết hơn!
