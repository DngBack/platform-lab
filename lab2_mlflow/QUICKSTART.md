# Lab 2: Quick Start Guide

## 🚀 Deploy MLflow trong 3 bước

### Bước 1: Deploy MLflow Server

```bash
cd ~/Desktop/platform-lab/lab2_mlflow
./scripts/deploy_mlflow.sh
```

### Bước 2: Verify

```bash
./scripts/check_mlflow_status.sh
```

### Bước 3: Connect từ Notebook

Trong notebook, chạy:

```python
import mlflow

# Set tracking URI
mlflow.set_tracking_uri("http://mlflow-service.mlflow.svc.cluster.local:5000")

# Test
experiments = mlflow.search_experiments()
print(f"Connected! Found {len(experiments)} experiments")
```

## 📊 Access MLflow UI

```bash
./scripts/port_forward_mlflow.sh
# Mở browser: http://localhost:5000
```

## 🧹 Cleanup

```bash
./scripts/cleanup_mlflow.sh
```

## 📝 Examples

1. **Test Connection**: `examples/test_mlflow_connection.py`
2. **Training Example**: `examples/simple_training_example.py`

Copy code vào notebook và chạy!




