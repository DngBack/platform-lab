# Lab 2: MLflow Server Setup and Integration with Notebooks

## 📋 Tổng Quan

Lab này hướng dẫn bạn cách:
- Deploy MLflow Tracking Server trên Kubernetes
- Setup persistent storage cho MLflow data
- Connect từ Jupyter Notebook tới MLflow Server
- Sử dụng MLflow để track experiments, metrics, và models

## 🎯 Mục Tiêu Học Tập

✅ Hiểu cách deploy ML service trên Kubernetes  
✅ Biết cách setup persistent storage cho ML data  
✅ Hiểu Service Discovery trong Kubernetes (DNS, Services)  
✅ Thực hành MLflow experiment tracking  
✅ Tích hợp MLflow với Jupyter Notebooks trong Kubernetes  

## 📁 Cấu Trúc Thư Mục

```
lab2_mlflow/
├── README.md                      # File này
├── manifests/                     # Kubernetes manifests
│   ├── namespace.yaml            # MLflow namespace
│   ├── pvc.yaml                  # PersistentVolumeClaim cho storage
│   ├── mlflow-deployment.yaml    # MLflow Server Deployment
│   └── mlflow-service.yaml       # MLflow Service
├── scripts/                       # Deployment scripts
│   ├── deploy_mlflow.sh          # Deploy MLflow Server
│   ├── check_mlflow_status.sh    # Check status
│   ├── port_forward_mlflow.sh    # Port-forward UI
│   └── cleanup_mlflow.sh         # Cleanup resources
└── examples/                      # Example code
    ├── test_mlflow_connection.py # Test connection
    └── simple_training_example.py # Training example với MLflow
```

## 🚀 Quick Start

### Prerequisites

- Kubernetes cluster đang chạy
- kubectl đã cài đặt và configured
- Đã hoàn thành Lab 1 (Notebook Controller setup)
- Một notebook đang chạy (từ Lab 1)

### Bước 1: Deploy MLflow Server

```bash
cd ~/Desktop/platform-lab/lab2_mlflow
chmod +x scripts/*.sh
./scripts/deploy_mlflow.sh
```

Script này sẽ:
- Tạo namespace `mlflow`
- Tạo PVC cho persistent storage (10Gi)
- Deploy MLflow Server
- Tạo Service để expose MLflow

**Thời gian:** 1-2 phút

### Bước 2: Verify Deployment

```bash
./scripts/check_mlflow_status.sh
```

Hoặc kiểm tra thủ công:

```bash
kubectl get pods -n mlflow
kubectl get svc -n mlflow
kubectl get pvc -n mlflow
```

### Bước 3: Access MLflow UI (Optional)

Để xem MLflow UI từ local machine:

```bash
./scripts/port_forward_mlflow.sh
# Hoặc
kubectl port-forward -n mlflow svc/mlflow-service 5000:5000
```

Sau đó mở browser: `http://localhost:5000`

### Bước 4: Connect từ Notebook

1. **Access notebook** (từ Lab 1):
   ```bash
   # Từ Lab 1, port-forward notebook
   kubectl port-forward -n default <notebook-pod> 8888:8888
   ```

2. **Cài MLflow trong notebook** (nếu chưa có):
   ```python
   !pip install mlflow scikit-learn
   ```

3. **Test connection**:
   ```python
   import mlflow
   
   # Set tracking URI (Service DNS trong Kubernetes)
   MLFLOW_TRACKING_URI = "http://mlflow-service.mlflow.svc.cluster.local:5000"
   mlflow.set_tracking_uri(MLFLOW_TRACKING_URI)
   
   # Test connection
   experiments = mlflow.search_experiments()
   print(f"Connected! Found {len(experiments)} experiments")
   ```

4. **Run example**:
   - Copy code từ `examples/test_mlflow_connection.py` vào notebook
   - Hoặc chạy `examples/simple_training_example.py`

## 📝 Chi Tiết

### 1. MLflow Architecture trong Kubernetes

```
┌─────────────────────────────────────────────────────┐
│  Kubernetes Cluster                                 │
│                                                     │
│  ┌────────────────┐    ┌──────────────────────┐   │
│  │ Jupyter        │    │  MLflow Server       │   │
│  │ Notebook Pod   │───▶│  (Deployment)        │   │
│  │                │    │  Port: 5000          │   │
│  └────────────────┘    └──────────────────────┘   │
│         │                        │                  │
│         │                        │                  │
│         │                 ┌──────────────────┐     │
│         │                 │  MLflow Service  │     │
│         │                 │  (ClusterIP)     │     │
│         │                 └──────────────────┘     │
│         │                        │                  │
│         │                 ┌──────────────────┐     │
│         └────────────────▶│  PVC             │     │
│                           │  (10Gi storage)  │     │
│                           └──────────────────┘     │
└─────────────────────────────────────────────────────┘
```

### 2. Service Discovery

Trong Kubernetes, services có DNS name theo format:
```
<service-name>.<namespace>.svc.cluster.local:<port>
```

Ví dụ:
```
mlflow-service.mlflow.svc.cluster.local:5000
```

Pods trong cluster có thể access service qua DNS name này.

### 3. Persistent Storage

MLflow Server cần persistent storage để:
- Lưu experiment metadata
- Lưu artifacts (models, plots, etc.)
- Dữ liệu không bị mất khi pod restart

PVC được mount vào `/mlflow` trong container.

### 4. MLflow Components

- **Tracking Server**: Backend để lưu trữ data
- **Backend Store**: Metadata (experiments, runs, params, metrics)
- **Artifact Store**: Files (models, images, etc.)

Trong setup này:
- Backend: `file:///mlflow/backend` (trong PVC)
- Artifacts: `file:///mlflow/artifacts` (trong PVC)

### 5. Example Usage

#### Basic Tracking

```python
import mlflow

mlflow.set_tracking_uri("http://mlflow-service.mlflow.svc.cluster.local:5000")
mlflow.set_experiment("my-experiment")

with mlflow.start_run():
    mlflow.log_param("learning_rate", 0.01)
    mlflow.log_metric("accuracy", 0.95)
    mlflow.log_artifact("model.pkl")
```

#### Model Logging

```python
import mlflow.sklearn

with mlflow.start_run():
    model = train_model()
    mlflow.sklearn.log_model(model, "model")
```

## 🔍 Troubleshooting

### MLflow Server không start

```bash
# Check pods
kubectl get pods -n mlflow
kubectl describe pod <pod-name> -n mlflow

# Check logs
kubectl logs -n mlflow <pod-name>
```

### Không connect được từ notebook

1. **Check service DNS**:
   ```bash
   # Từ notebook pod
   kubectl exec -it <notebook-pod> -n <namespace> -- nslookup mlflow-service.mlflow.svc.cluster.local
   ```

2. **Check network connectivity**:
   ```bash
   # Từ notebook pod
   kubectl exec -it <notebook-pod> -n <namespace> -- curl http://mlflow-service.mlflow.svc.cluster.local:5000
   ```

3. **Check firewall/network policies**:
   - Đảm bảo không có NetworkPolicy block traffic
   - Namespace có thể access nhau

### PVC không bound

```bash
# Check PVC status
kubectl get pvc -n mlflow

# Check StorageClass
kubectl get storageclass

# Nếu không có StorageClass, cluster sẽ dùng default
```

## 🧹 Cleanup

Để xóa tất cả MLflow resources:

```bash
./scripts/cleanup_mlflow.sh
```

Hoặc manual:

```bash
kubectl delete namespace mlflow
```

**Lưu ý:** Xóa namespace sẽ xóa tất cả data trong MLflow!

## 📚 Tài Liệu Tham Khảo

- [MLflow Documentation](https://www.mlflow.org/docs/latest/index.html)
- [MLflow Tracking](https://www.mlflow.org/docs/latest/tracking.html)
- [Kubernetes Services](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)

## ✅ Checklist

- [ ] MLflow Server deployed và running
- [ ] PVC bound thành công
- [ ] Service created và accessible
- [ ] Connect từ notebook thành công
- [ ] Test connection script chạy OK
- [ ] Training example chạy OK
- [ ] MLflow UI accessible qua port-forward
- [ ] Hiểu cách Service Discovery hoạt động

## 🎓 Bài Học

Sau khi hoàn thành Lab 2, bạn đã học được:

1. ✅ Cách deploy ML service trên Kubernetes
2. ✅ Setup persistent storage cho ML applications
3. ✅ Service Discovery và DNS trong Kubernetes
4. ✅ MLflow experiment tracking
5. ✅ Tích hợp services trong Kubernetes cluster
6. ✅ Best practices cho ML workflows

---

**Tác giả:** Platform Lab  
**Cập nhật:** 2024

