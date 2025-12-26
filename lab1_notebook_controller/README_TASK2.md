# Task 2: Deploy Notebook Controller Only

## 📋 Tổng Quan

Task này giúp bạn hiểu cách deploy chỉ **Notebook Controller** mà không cần full Kubeflow platform. Bạn sẽ học cách:
- Deploy minimal setup (chỉ Notebook Controller)
- Tạo Notebook resources bằng YAML
- Access và sử dụng Notebooks
- So sánh với full Kubeflow deployment

## 🎯 Mục Tiêu Học Tập

✅ Hiểu cách deploy component độc lập  
✅ Biết cách tạo và quản lý Notebook resources  
✅ Hiểu Notebook CRD và Controller  
✅ So sánh minimal vs full deployment  

## 🔄 So Sánh Task 1 vs Task 2

| Aspect | Task 1 (Full Kubeflow) | Task 2 (Notebook Controller Only) |
|--------|------------------------|-----------------------------------|
| **Components** | ~18 components | 1 component |
| **Namespaces** | 7+ namespaces | 1 namespace |
| **Resources** | ~100+ pods | ~2-3 pods |
| **Setup Time** | 10-15 phút | 2-3 phút |
| **Use Case** | Full ML platform | Chỉ cần Jupyter Notebooks |
| **Complexity** | Cao | Thấp |

## 📁 Cấu Trúc Thư Mục

```
lab1_notebook_controller/
├── scripts/
│   ├── 05_cleanup.sh                    # Cleanup full Kubeflow (Task 1)
│   ├── 06_deploy_notebook_controller.sh # Deploy chỉ Notebook Controller
│   ├── 07_create_notebook.sh            # Tạo Notebook từ YAML
│   ├── 08_access_notebook.sh            # Access Notebook
│   └── 09_check_notebook_status.sh      # Check Notebook status
├── examples/
│   └── notebooks/
│       ├── basic-notebook.yaml          # Basic Jupyter notebook
│       ├── tensorflow-notebook.yaml     # TensorFlow notebook
│       └── gpu-notebook.yaml            # GPU notebook
└── manifests/                            # Kubeflow manifests
```

## 🚀 Quick Start

### Bước 1: Cleanup Full Kubeflow (nếu đã deploy Task 1)

Nếu bạn đã deploy full Kubeflow ở Task 1, cần cleanup trước:

```bash
cd ~/platform-lab/lab1_notebook_controller
./scripts/05_cleanup.sh
```

**Lưu ý:** Script sẽ hỏi xác nhận và có option để xóa CRDs.

### Bước 2: Deploy Notebook Controller

```bash
./scripts/06_deploy_notebook_controller.sh
```

Script này sẽ:
- Kiểm tra cluster connection
- Deploy Notebook Controller với standalone overlay
- Tạo CRD `notebooks.kubeflow.org`
- Tạo RBAC (Roles, RoleBindings)
- Deploy controller pod
- Verify deployment

**Thời gian:** 2-3 phút

**Namespace:** `notebook-controller-system`

### Bước 3: Tạo Notebook

Có 2 cách tạo Notebook:

#### Cách 1: Dùng Script (Khuyến nghị)

```bash
./scripts/07_create_notebook.sh
```

Script sẽ hỏi:
- Namespace (default: `default`)
- Notebook type:
  1. Basic Jupyter (CPU only)
  2. Jupyter with TensorFlow (CPU)
  3. Jupyter with TensorFlow (GPU)
  4. Custom YAML file

#### Cách 2: Dùng YAML trực tiếp

```bash
# Basic notebook
kubectl apply -f examples/notebooks/basic-notebook.yaml

# TensorFlow notebook
kubectl apply -f examples/notebooks/tensorflow-notebook.yaml

# GPU notebook (nếu cluster có GPU)
kubectl apply -f examples/notebooks/gpu-notebook.yaml
```

### Bước 4: Kiểm Tra Status

```bash
./scripts/09_check_notebook_status.sh
```

Hoặc manual:

```bash
# List tất cả notebooks
kubectl get notebooks -A

# Chi tiết một notebook
kubectl describe notebook <notebook-name> -n <namespace>

# Xem pods
kubectl get pods -l notebook-name=<notebook-name> -n <namespace>
```

### Bước 5: Access Notebook

```bash
./scripts/08_access_notebook.sh <notebook-name> <namespace>
```

Hoặc manual:

```bash
# Get pod name
POD_NAME=$(kubectl get pods -n <namespace> -l notebook-name=<notebook-name> -o jsonpath='{.items[0].metadata.name}')

# Port forward
kubectl port-forward -n <namespace> $POD_NAME 8888:8888
```

Sau đó mở browser: `http://localhost:8888`

**Lấy token:**
```bash
kubectl logs -n <namespace> $POD_NAME | grep token
```

## 📝 Thực Hành Chi Tiết

### 1. Hiểu Notebook CRD

Notebook là một Custom Resource được định nghĩa bởi CRD:

```yaml
apiVersion: kubeflow.org/v1
kind: Notebook
metadata:
  name: my-notebook
  namespace: default
spec:
  template:
    spec:
      containers:
      - name: my-notebook
        image: kubeflownotebookswg/jupyter-scipy:latest
        resources:
          requests:
            cpu: "1.0"
            memory: 2Gi
          limits:
            cpu: "2.0"
            memory: 4Gi
  volumes:
  - name: workspace
    persistentVolumeClaim:
      claimName: my-notebook-workspace
```

**Các thành phần:**
- `metadata`: Tên và namespace
- `spec.template.spec.containers`: Container spec (giống Pod)
- `spec.volumes`: Volumes để persist data

### 2. Notebook Controller Hoạt Động Như Thế Nào?

1. **User tạo Notebook resource** → `kubectl apply -f notebook.yaml`
2. **Controller detect** → Watch Notebook resources
3. **Controller tạo Pod** → Dựa trên `spec.template`
4. **Controller tạo Service** → Expose notebook port
5. **Controller update status** → `status.ready = true`

**Kiểm tra resources được tạo:**

```bash
# Pod
kubectl get pods -l notebook-name=<notebook-name>

# Service
kubectl get svc -l notebook-name=<notebook-name>

# PVC (nếu có)
kubectl get pvc -l notebook-name=<notebook-name>
```

### 3. Test CPU Workload

Sau khi access notebook, test với code:

```python
import numpy as np
import time

# Matrix multiplication test
size = 2000
a = np.random.rand(size, size)
b = np.random.rand(size, size)

start = time.time()
c = np.dot(a, b)
end = time.time()

print(f"Matrix {size}x{size} multiplication: {end - start:.2f} seconds")
```

### 4. Test GPU Workload (Optional)

Nếu có GPU notebook:

```python
import tensorflow as tf
import numpy as np

# Check GPU
print("GPU Available:", tf.config.list_physical_devices('GPU'))

# GPU computation
with tf.device('/GPU:0'):
    a = tf.random.normal([5000, 5000])
    b = tf.random.normal([5000, 5000])
    c = tf.matmul(a, b)
    print("GPU computation completed")
```

## 🔍 Kiểm Tra và Debug

### Xem Controller Logs

```bash
kubectl logs -n notebook-controller-system -l app=notebook-controller
```

### Xem Notebook Events

```bash
kubectl get events -n <namespace> --field-selector involvedObject.name=<notebook-name>
```

### Describe Notebook

```bash
kubectl describe notebook <notebook-name> -n <namespace>
```

### Xem Pod Logs

```bash
kubectl logs -n <namespace> -l notebook-name=<notebook-name>
```

### Debug Pod Issues

```bash
# Xem pod status
kubectl get pod <pod-name> -n <namespace> -o yaml

# Xem events
kubectl describe pod <pod-name> -n <namespace>

# Exec vào pod
kubectl exec -it <pod-name> -n <namespace> -- bash
```

## 🧹 Cleanup

### Xóa Notebook

```bash
kubectl delete notebook <notebook-name> -n <namespace>
```

**Lưu ý:** Controller sẽ tự động xóa Pod và Service, nhưng **PVC không tự động xóa** (để bảo vệ data).

Xóa PVC thủ công nếu cần:

```bash
kubectl delete pvc <pvc-name> -n <namespace>
```

### Xóa Notebook Controller

```bash
# Xóa controller
kubectl delete -k manifests/apps/jupyter/notebook-controller/upstream/overlays/standalone

# Xóa CRD (optional)
kubectl delete crd notebooks.kubeflow.org
```

## 📊 So Sánh Architecture

### Full Kubeflow (Task 1)

```
┌─────────────────────────────────────┐
│         Istio Service Mesh          │
├─────────────────────────────────────┤
│  Central Dashboard                  │
│  ├── Notebook Controller            │
│  ├── Jupyter Web App                │
│  ├── Pipelines                      │
│  ├── Katib                          │
│  ├── KServe                         │
│  └── ... (18 components)           │
└─────────────────────────────────────┘
```

### Notebook Controller Only (Task 2)

```
┌─────────────────────────────────────┐
│    Notebook Controller              │
│    ├── CRD: notebooks.kubeflow.org  │
│    ├── Controller Pod               │
│    └── RBAC                         │
└─────────────────────────────────────┘
         │
         ▼
    Notebook Resources
    ├── Pod (Jupyter)
    ├── Service
    └── PVC
```

## ❓ Troubleshooting

### Notebook không start

**Nguyên nhân:** Không đủ resources

**Giải pháp:**
```bash
# Check node resources
kubectl describe nodes

# Check pod events
kubectl describe pod <pod-name> -n <namespace>
```

### Không access được notebook

**Nguyên nhân:** Port-forward chưa chạy hoặc pod chưa ready

**Giải pháp:**
```bash
# Check pod status
kubectl get pods -l notebook-name=<notebook-name>

# Check port-forward
kubectl get pods -n <namespace> | grep <notebook-name>
```

### PVC không được tạo

**Nguyên nhân:** Storage class không có hoặc không đúng

**Giải pháp:**
```bash
# Check storage classes
kubectl get storageclass

# Check PVC
kubectl describe pvc <pvc-name> -n <namespace>
```

### GPU không hoạt động

**Nguyên nhân:** 
- Cluster không có GPU nodes
- NVIDIA device plugin chưa được cài

**Giải pháp:**
```bash
# Check GPU nodes
kubectl get nodes -l accelerator=nvidia-tesla-k80

# Check device plugin
kubectl get pods -n kube-system | grep nvidia
```

## ✅ Checklist Hoàn Thành

- [ ] Full Kubeflow đã được cleanup (nếu có)
- [ ] Notebook Controller deployed thành công
- [ ] CRD `notebooks.kubeflow.org` tồn tại
- [ ] Controller pod đang chạy
- [ ] Notebook được tạo thành công
- [ ] Notebook pod đang chạy
- [ ] Access được notebook qua port-forward
- [ ] Test CPU workload thành công
- [ ] (Optional) Test GPU workload thành công
- [ ] Hiểu cách Notebook Controller hoạt động

## 🎓 Kiến Thức Đạt Được

Sau Task 2, bạn nên hiểu:

**1. Minimal Deployment**
- Cách deploy component độc lập
- So sánh với full platform
- Trade-offs giữa simplicity và features

**2. Custom Resources**
- CRD là gì
- Cách controller watch và reconcile
- Relationship giữa CR và Pods/Services

**3. Notebook Controller**
- Controller pattern trong Kubernetes
- Cách controller tạo Pods từ CR spec
- Volume management

**4. Resource Management**
- CPU/Memory requests và limits
- GPU resources
- Persistent volumes

## 🔜 Next: Task 3 (Optional)

Sau khi hoàn thành Task 2:
1. Chuẩn bị demo
2. Giải thích architecture
3. So sánh Task 1 vs Task 2

---

**Questions?** Xem thêm:
- [Kubeflow Notebook Controller Docs](https://www.kubeflow.org/docs/components/notebooks/)
- [Kubernetes CRDs](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/)


