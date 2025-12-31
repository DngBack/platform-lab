# 📘 GUIDE.md - Hướng Dẫn Chi Tiết Notebook Controller

Tài liệu này hướng dẫn **từng bước** sử dụng **kubectl commands** để deploy và quản lý Notebook Controller mà **không cần dùng scripts**.

---

## 📋 Mục Lục

1. [Kiến Thức Cơ Bản](#1-kiến-thức-cơ-bản)
2. [Kiểm Tra Môi Trường](#2-kiểm-tra-môi-trường)
3. [Deploy Notebook Controller](#3-deploy-notebook-controller)
4. [Tạo Notebook](#4-tạo-notebook)
5. [Truy Cập Notebook](#5-truy-cập-notebook)
6. [Quản Lý Notebook](#6-quản-lý-notebook)
7. [Troubleshooting](#7-troubleshooting)
8. [Các Khái Niệm Quan Trọng](#8-các-khái-niệm-quan-trọng)
9. [Quick Reference](#9-quick-reference)
10. [Best Practices](#10-best-practices)

---

## 1. Kiến Thức Cơ Bản

### 1.1. Kubernetes Resources

**Namespace:**
- Là một "virtual cluster" trong cluster thật
- Dùng để isolate resources
- Mỗi namespace có thể có resources riêng

**Pod:**
- Đơn vị nhỏ nhất trong Kubernetes
- Chứa một hoặc nhiều containers
- Có lifecycle riêng (Pending → Running → Succeeded/Failed)

**Service:**
- Expose pods ra network
- Có IP và DNS name ổn định
- Load balance traffic tới pods

**PersistentVolumeClaim (PVC):**
- Request storage từ cluster
- Bind với PersistentVolume (PV)
- Dùng để mount vào pods

**CustomResourceDefinition (CRD):**
- Mở rộng Kubernetes API
- Cho phép tạo custom resources
- Notebook là một CRD

**Controller:**
- Process watch resources và reconcile
- Đảm bảo desired state = actual state
- Notebook Controller watch Notebook resources

### 1.2. kubectl Commands Cơ Bản

**Format chung:**
```bash
kubectl <command> <resource-type> <resource-name> [flags]
```

**Các command thường dùng:**
- `get`: Xem resources
- `create`: Tạo resource mới
- `apply`: Apply manifest (create hoặc update)
- `delete`: Xóa resource
- `describe`: Xem chi tiết resource
- `logs`: Xem logs của pod
- `exec`: Chạy lệnh trong pod
- `port-forward`: Forward port từ local → pod

---

## 2. Kiểm Tra Môi Trường

### 2.1. Kiểm Tra Cluster Connection

```bash
kubectl cluster-info
```

**Giải thích:**
- Kiểm tra kết nối tới Kubernetes cluster
- Hiển thị API server URL
- Nếu không kết nối được → kiểm tra kubeconfig

**Output mẫu:**
```
Kubernetes control plane is running at https://192.168.49.2:8443
CoreDNS is running at https://192.168.49.2:8443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

**Chú ý:**
- Nếu lỗi: `The connection to the server <host> was refused`
  → Cluster chưa start hoặc kubeconfig sai

### 2.2. Kiểm Tra Nodes

```bash
kubectl get nodes
```

**Giải thích:**
- Liệt kê tất cả nodes trong cluster
- Xem status (Ready/NotReady)
- Xem thông tin node (OS, kubelet version)

**Output mẫu:**
```
NAME       STATUS   ROLES           AGE   VERSION
minikube   Ready    control-plane   5d    v1.28.0
```

**Xem chi tiết node:**
```bash
kubectl describe node <node-name>
```

**Chú ý:**
- Node phải ở trạng thái `Ready`
- Nếu `NotReady` → kiểm tra kubelet, network

### 2.3. Kiểm Tra Namespaces

```bash
kubectl get namespaces
# Hoặc viết tắt
kubectl get ns
```

**Giải thích:**
- Liệt kê tất cả namespaces
- Namespace mặc định: `default`, `kube-system`, `kube-public`, `kube-node-lease`

**Xem pods trong namespace:**
```bash
kubectl get pods -n <namespace>
```

**Chú ý:**
- Mỗi resource thuộc một namespace
- Nếu không chỉ định `-n`, dùng namespace `default`

### 2.4. Xem Tất Cả Pods

```bash
# Xem pods trong tất cả namespaces
kubectl get pods -A

# Hoặc
kubectl get pods --all-namespaces

# Xem pods đang Running
kubectl get pods -A --field-selector=status.phase=Running
```

**Giải thích:**
- `-A` hoặc `--all-namespaces`: Xem tất cả namespaces
- `--field-selector=status.phase=Running`: Chỉ xem pods Running

---

## 3. Deploy Notebook Controller

### 3.1. Kiểm Tra Manifests Directory

```bash
ls -la manifests/apps/jupyter/notebook-controller/upstream
```

**Giải thích:**
- Kiểm tra thư mục manifests có tồn tại không
- Cần có thư mục `overlays/standalone/`

**Cấu trúc thư mục:**
```
manifests/apps/jupyter/notebook-controller/upstream/
├── base/              # Base manifests
├── overlays/
│   ├── kubeflow/      # Overlay cho Kubeflow
│   └── standalone/    # Overlay standalone (không cần Kubeflow)
└── ...
```

**Chú ý:**
- Nếu không có → clone manifests:
  ```bash
  git clone https://github.com/kubeflow/manifests.git
  ```

### 3.2. Chuyển Vào Thư Mục Notebook Controller

```bash
cd manifests/apps/jupyter/notebook-controller/upstream
```

**Giải thích:**
- `kustomize build` dùng relative paths
- Phải ở đúng thư mục để kustomize tìm được `base/` và `overlays/`

**Chú ý:**
- **QUAN TRỌNG:** Phải `cd` vào đúng thư mục trước khi chạy `kustomize build`
- Nếu không → lỗi: `not a valid directory: evalsymlink failure`

### 3.3. Build Manifests với Kustomize

```bash
kustomize build overlays/standalone
```

**Giải thích:**
- `kustomize`: Tool customize Kubernetes manifests
- `build`: Build manifests từ kustomization.yaml
- `overlays/standalone`: Overlay không cần Istio/Kubeflow

**Cách hoạt động:**
1. Đọc `overlays/standalone/kustomization.yaml`
2. Reference tới `../../base/`
3. Apply namespace: `notebook-controller-system`
4. Set config: `USE_ISTIO=false`
5. Output: Combined YAML manifests

**Output:**
- YAML manifests (stdout)
- Gồm: CRD, RBAC, Deployment, Service

**Chú ý:**
- Output là YAML, không apply vào cluster
- Để apply: pipe sang `kubectl apply`

### 3.4. Apply Manifests

```bash
kustomize build overlays/standalone | kubectl apply -f -
```

**Giải thích:**
- `|`: Pipe operator (lấy output từ lệnh trước → input cho lệnh sau)
- `kubectl apply`: Apply manifests vào cluster
- `-f -`: Đọc từ stdin (thay vì file)

**Cách hoạt động:**
1. `kustomize build` → output YAML
2. Pipe sang `kubectl apply`
3. `kubectl apply` đọc YAML từ stdin
4. Apply vào cluster (create hoặc update)

**Output mẫu:**
```
customresourcedefinition.apiextensions.k8s.io/notebooks.kubeflow.org created
namespace/notebook-controller-system created
serviceaccount/notebook-controller created
role.rbac.authorization.k8s.io/notebook-controller created
rolebinding.rbac.authorization.k8s.io/notebook-controller created
deployment.apps/notebook-controller created
service/notebook-controller created
```

**Chú ý:**
- Nếu resource đã tồn tại → update
- Nếu chưa tồn tại → create
- `apply` là idempotent (chạy nhiều lần an toàn)

### 3.5. Chờ CRD Established

```bash
kubectl wait --for condition=established --timeout=60s crd/notebooks.kubeflow.org
```

**Giải thích:**
- `kubectl wait`: Đợi resource đạt condition
- `--for condition=established`: CRD condition khi đã được API server accept
- `--timeout=60s`: Timeout sau 60 giây
- `crd/notebooks.kubeflow.org`: CRD name

**CRD Established Condition:**
- CRD phải established trước khi tạo custom resources
- Nếu không established → tạo Notebook sẽ fail với lỗi: `no matches for kind "Notebook"`

**Chú ý:**
- Nếu timeout → CRD có thể có vấn đề
- Kiểm tra: `kubectl get crd notebooks.kubeflow.org`

### 3.6. Kiểm Tra CRD

```bash
kubectl get crd notebooks.kubeflow.org
```

**Giải thích:**
- Xem CRD đã được tạo chưa
- Xem thông tin CRD (API version, scope, etc.)

**Output mẫu:**
```
NAME                      CREATED AT
notebooks.kubeflow.org    2024-01-15T10:30:00Z
```

**Xem chi tiết CRD:**
```bash
kubectl describe crd notebooks.kubeflow.org
```

### 3.7. Chờ Controller Pod Ready

```bash
kubectl wait --for=condition=ready pod -l app=notebook-controller --timeout=180s -n notebook-controller-system
```

**Giải thích:**
- `--for=condition=ready`: Đợi pod ready (containers started, readiness probe passed)
- `-l app=notebook-controller`: Label selector (chọn pods có label `app=notebook-controller`)
- `-n notebook-controller-system`: Namespace
- `--timeout=180s`: Timeout 3 phút

**Pod Ready Condition:**
- Tất cả containers đã start
- Readiness probe passed (nếu có)
- Pod có thể nhận traffic

**Chú ý:**
- Nếu timeout → kiểm tra pod logs
- Pod có thể đang pull image (mất thời gian)

### 3.8. Kiểm Tra Controller Pods

```bash
kubectl get pods -n notebook-controller-system
```

**Giải thích:**
- Xem pods trong namespace `notebook-controller-system`
- Xem status (Running, Pending, Error)

**Output mẫu:**
```
NAME                                  READY   STATUS    RESTARTS   AGE
notebook-controller-7d5f8c9b4f-abc12  1/1     Running   0          2m
```

**Xem chi tiết pod:**
```bash
kubectl describe pod <pod-name> -n notebook-controller-system
```

**Xem logs:**
```bash
kubectl logs -n notebook-controller-system -l app=notebook-controller
```

**Chú ý:**
- Pod phải ở trạng thái `Running`
- `READY 1/1` nghĩa là 1 container đã ready / tổng 1 container

### 3.9. Kiểm Tra RBAC

```bash
kubectl get roles -n notebook-controller-system
kubectl get rolebindings -n notebook-controller-system
```

**Giải thích:**
- **Role**: Định nghĩa permissions trong namespace
- **RoleBinding**: Bind Role với ServiceAccount
- Controller cần permissions để tạo Pods, Services, etc.

**Xem chi tiết Role:**
```bash
kubectl describe role notebook-controller -n notebook-controller-system
```

**Chú ý:**
- Nếu controller không hoạt động → kiểm tra RBAC permissions

---

## 4. Tạo Notebook

### 4.1. Tạo Namespace (Nếu Cần)

```bash
kubectl create namespace <namespace-name>
```

**Giải thích:**
- Tạo namespace mới
- Namespace dùng để isolate resources

**Ví dụ:**
```bash
kubectl create namespace my-notebooks
```

**Kiểm tra namespace:**
```bash
kubectl get namespace <namespace-name>
```

**Chú ý:**
- Nếu namespace đã tồn tại → lỗi (có thể ignore)
- Có thể dùng namespace `default` (không cần tạo)

### 4.2. Tạo PVC (PersistentVolumeClaim)

**Tạo file PVC YAML:**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: tensorflow-notebook-workspace
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
```

**Apply PVC:**
```bash
kubectl apply -f <pvc-file.yaml>
```

**Hoặc tạo trực tiếp:**
```bash
kubectl create -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: tensorflow-notebook-workspace
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
EOF
```

**Giải thích:**
- **PVC**: Request storage từ cluster
- **accessModes**: `ReadWriteOnce` = chỉ 1 pod có thể mount
- **storage**: 20Gi = 20 gigabytes

**Kiểm tra PVC:**
```bash
kubectl get pvc -n default
```

**Output mẫu:**
```
NAME                            STATUS   VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
tensorflow-notebook-workspace   Bound    pvc-xxx  20Gi       RWO            standard       1m
```

**Chú ý:**
- **STATUS**: Phải là `Bound` (đã bind với PV)
- Nếu `Pending` → kiểm tra StorageClass, node có storage không

### 4.3. Tạo Notebook Resource

**Tạo file Notebook YAML:**
```yaml
apiVersion: kubeflow.org/v1
kind: Notebook
metadata:
  name: tensorflow-notebook
  namespace: default
spec:
  template:
    spec:
      containers:
      - name: tensorflow-notebook
        image: kubeflownotebookswg/jupyter-tensorflow-full:latest
        resources:
          requests:
            cpu: "2.0"
            memory: 4Gi
          limits:
            cpu: "2.0"
            memory: 4Gi
      volumes:
      - name: workspace
        persistentVolumeClaim:
          claimName: tensorflow-notebook-workspace
```

**Apply Notebook:**
```bash
kubectl apply -f examples/notebooks/tensorflow-notebook.yaml
```

**Giải thích:**
- **apiVersion**: `kubeflow.org/v1` (từ CRD)
- **kind**: `Notebook` (custom resource)
- **spec.template**: Pod template (controller sẽ tạo pod từ đây)
- **resources**: CPU/Memory requests và limits
- **volumes**: Mount PVC vào pod

**Cách hoạt động:**
1. User tạo Notebook resource
2. Controller detect (watch)
3. Controller đọc `spec.template`
4. Controller tạo Pod từ template
5. Controller tạo Service để expose
6. Controller update `status.ready`

**Kiểm tra Notebook:**
```bash
kubectl get notebooks -n default
```

**Output mẫu:**
```
NAME                 READY   AGE
tensorflow-notebook  True    2m
```

**Xem chi tiết:**
```bash
kubectl describe notebook tensorflow-notebook -n default
```

**Chú ý:**
- Notebook resource ≠ Pod
- Controller sẽ tự động tạo Pod từ Notebook
- Phải đợi controller tạo pod (có thể mất vài giây)

### 4.4. Kiểm Tra Pod Được Tạo

```bash
kubectl get pods -n default -l notebook-name=tensorflow-notebook
```

**Giải thích:**
- `-l notebook-name=tensorflow-notebook`: Label selector
- Controller tự động thêm label `notebook-name=<notebook-name>` vào pod

**Output mẫu:**
```
NAME                    READY   STATUS    RESTARTS   AGE
tensorflow-notebook-0   1/1     Running   0          1m
```

**Xem chi tiết pod:**
```bash
kubectl describe pod tensorflow-notebook-0 -n default
```

**Xem logs:**
```bash
kubectl logs -n default tensorflow-notebook-0
```

**Chú ý:**
- Pod name format: `<notebook-name>-0`
- Nếu STATUS = `Pending` → có thể đang pull image
- Nếu STATUS = `ImagePullBackOff` → image không tồn tại hoặc network issue

### 4.5. Kiểm Tra Service Được Tạo

```bash
kubectl get svc -n default -l notebook-name=tensorflow-notebook
```

**Giải thích:**
- Controller tự động tạo Service
- Service expose pod ra network
- Label: `notebook-name=<notebook-name>`

**Output mẫu:**
```
NAME                 TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
tensorflow-notebook  ClusterIP   10.96.123.45   <none>        80/TCP     1m
```

**Xem chi tiết:**
```bash
kubectl describe svc tensorflow-notebook -n default
```

**Chú ý:**
- Service type: `ClusterIP` (chỉ accessible trong cluster)
- Để access từ ngoài → dùng port-forward hoặc Ingress

### 4.6. Chờ Notebook Ready

```bash
kubectl wait --for=condition=ready notebook/tensorflow-notebook -n default --timeout=300s
```

**Giải thích:**
- Đợi Notebook resource đạt condition `ready`
- Timeout 5 phút

**Hoặc kiểm tra thủ công:**
```bash
kubectl get notebook tensorflow-notebook -n default -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
```

**Output:**
- `True` = ready
- `False` = chưa ready

**Chú ý:**
- Notebook ready = Pod running + Service created
- Có thể mất vài phút (pull image, start containers)

---

## 5. Truy Cập Notebook

### 5.1. Lấy Pod Name

```bash
POD_NAME=$(kubectl get pods -n default -l notebook-name=tensorflow-notebook -o jsonpath='{.items[0].metadata.name}')
echo $POD_NAME
```

**Giải thích:**
- `kubectl get pods`: Lấy pods
- `-l notebook-name=tensorflow-notebook`: Label selector
- `-o jsonpath='{.items[0].metadata.name}'`: Extract pod name từ JSON
- `$()`: Command substitution (lấy output của lệnh)

**Output:**
```
tensorflow-notebook-0
```

**Chú ý:**
- Phải đảm bảo pod đã tồn tại
- Nếu không có pod → biến `POD_NAME` sẽ rỗng

### 5.2. Kiểm Tra Pod Ready

```bash
kubectl get pods -n default -l notebook-name=tensorflow-notebook -o jsonpath='{.items[0].status.containerStatuses[0].ready}'
```

**Giải thích:**
- Kiểm tra container đầu tiên đã ready chưa
- Output: `true` hoặc `false`

**Kiểm tra pod phase:**
```bash
kubectl get pods -n default -l notebook-name=tensorflow-notebook -o jsonpath='{.items[0].status.phase}'
```

**Output:**
- `Running` = pod đang chạy
- `Pending` = đang chờ
- `Failed` = lỗi

**Chú ý:**
- Pod phải `Running` và `ready=true` trước khi port-forward

### 5.3. Lấy Token

**Method 1: Từ jupyter server list (JupyterLab mới):**
```bash
kubectl exec -n default $POD_NAME -- jupyter server list
```

**Giải thích:**
- `kubectl exec`: Chạy lệnh trong pod
- `-n default`: Namespace
- `$POD_NAME`: Pod name
- `--`: Separator (sau `--` là lệnh chạy trong pod)
- `jupyter server list`: Liệt kê Jupyter servers

**Output mẫu:**
```
Currently running servers:
http://0.0.0.0:8888/notebook/default/tensorflow-notebook/lab?token=abc123def456...
```

**Extract token:**
```bash
TOKEN=$(kubectl exec -n default $POD_NAME -- jupyter server list 2>/dev/null | grep -oP 'token=\K[^\s]+' | head -1)
echo $TOKEN
```

**Giải thích:**
- `grep -oP 'token=\K[^\s]+'`: Regex extract token (sau `token=`)
- `head -1`: Lấy token đầu tiên
- `2>/dev/null`: Ẩn stderr

**Method 2: Từ jupyter notebook list (Jupyter cũ):**
```bash
kubectl exec -n default $POD_NAME -- jupyter notebook list
```

**Method 3: Từ logs:**
```bash
kubectl logs -n default $POD_NAME | grep -i token
```

**Chú ý:**
- Token cần để authenticate vào JupyterLab
- Có thể không cần token nếu đã authenticated qua kubectl

### 5.4. Port-Forward

```bash
kubectl port-forward -n default $POD_NAME 8888:8888
```

**Giải thích:**
- `kubectl port-forward`: Forward port từ local → pod
- `-n default`: Namespace
- `$POD_NAME`: Pod name
- `8888:8888`: `local-port:pod-port`

**Cách hoạt động:**
1. Tạo tunnel từ local machine → pod
2. Traffic tới `localhost:8888` → forward tới port 8888 trong pod
3. Chạy trong foreground (block terminal)

**Output mẫu:**
```
Forwarding from 127.0.0.1:8888 -> 8888
Forwarding from [::1]:8888 -> 8888
```

**Port-forward trong background:**
```bash
kubectl port-forward -n default $POD_NAME 8888:8888 &
```

**Dừng port-forward:**
- Foreground: Nhấn `Ctrl+C`
- Background: `kill <PID>` hoặc `killall kubectl`

**Chú ý:**
- Port-forward chỉ hoạt động khi process đang chạy
- Nếu đóng terminal → port-forward dừng
- Có thể dùng port khác: `8889:8888` (local port 8889 → pod port 8888)

### 5.5. Truy Cập Browser

**URL format:**
```
http://localhost:8888/notebook/{namespace}/{notebook-name}/lab
```

**Ví dụ:**
```
http://localhost:8888/notebook/default/tensorflow-notebook/lab
```

**Với token:**
```
http://localhost:8888/notebook/default/tensorflow-notebook/lab?token=<TOKEN>
```

**Giải thích:**
- JupyterLab dùng **path-based routing**
- Không serve ở root `/`
- Path: `/notebook/{namespace}/{notebook-name}/lab`

**Chú ý:**
- Nếu 404 → kiểm tra path có đúng không
- Nếu không có token → JupyterLab sẽ prompt nhập token

---

## 6. Quản Lý Notebook

### 6.1. Xem Tất Cả Notebooks

```bash
# Trong namespace cụ thể
kubectl get notebooks -n default

# Tất cả namespaces
kubectl get notebooks -A
```

**Output mẫu:**
```
NAME                 READY   AGE
tensorflow-notebook  True    1h
basic-notebook       True    30m
```

### 6.2. Xem Chi Tiết Notebook

```bash
kubectl describe notebook tensorflow-notebook -n default
```

**Giải thích:**
- Hiển thị thông tin chi tiết:
  - Metadata (name, namespace, labels)
  - Spec (template, resources)
  - Status (conditions, ready)
  - Events

**Chú ý:**
- Phần `Events` rất hữu ích để debug

### 6.3. Xem Pods Của Notebook

```bash
kubectl get pods -n default -l notebook-name=tensorflow-notebook
```

**Xem tất cả pods:**
```bash
kubectl get pods -n default
```

### 6.4. Xem Logs

```bash
# Logs của pod
kubectl logs -n default tensorflow-notebook-0

# Logs real-time (follow)
kubectl logs -n default tensorflow-notebook-0 -f

# Logs với tail
kubectl logs -n default tensorflow-notebook-0 --tail=100
```

**Giải thích:**
- `-f`: Follow (hiển thị logs mới)
- `--tail=100`: Chỉ hiển thị 100 dòng cuối

### 6.5. Exec Vào Pod

```bash
kubectl exec -it -n default tensorflow-notebook-0 -- /bin/bash
```

**Giải thích:**
- `-it`: Interactive terminal
- `-- /bin/bash`: Chạy bash shell trong pod

**Chạy lệnh trong pod:**
```bash
kubectl exec -n default tensorflow-notebook-0 -- ls -la /home/jovyan
```

**Chú ý:**
- Sau khi exec, có thể chạy lệnh như trong container
- Exit: gõ `exit` hoặc `Ctrl+D`

### 6.6. Xóa Notebook

```bash
kubectl delete notebook tensorflow-notebook -n default
```

**Giải thích:**
- Xóa Notebook resource
- Controller sẽ tự động xóa Pod và Service

**Xóa PVC (nếu muốn xóa storage):**
```bash
kubectl delete pvc tensorflow-notebook-workspace -n default
```

**Chú ý:**
- Xóa Notebook → Pod và Service tự động xóa
- PVC không tự động xóa (phải xóa thủ công)
- Xóa PVC → mất dữ liệu trong workspace

### 6.7. Update Notebook

**Cách 1: Sửa YAML và apply lại:**
```bash
# Sửa file YAML
vim examples/notebooks/tensorflow-notebook.yaml

# Apply lại
kubectl apply -f examples/notebooks/tensorflow-notebook.yaml
```

**Cách 2: Edit trực tiếp:**
```bash
kubectl edit notebook tensorflow-notebook -n default
```

**Chú ý:**
- Một số thay đổi (như image) → pod sẽ restart
- Một số thay đổi (như resources) → cần recreate pod

---

## 7. Troubleshooting

### 7.1. Pod Không Start

**Kiểm tra pod status:**
```bash
kubectl get pods -n default
kubectl describe pod <pod-name> -n default
```

**Các status thường gặp:**
- `Pending`: Đang chờ resources (CPU, memory, storage)
- `ImagePullBackOff`: Không pull được image
- `CrashLoopBackOff`: Container crash liên tục
- `Error`: Container lỗi

**Xem events:**
```bash
kubectl get events -n default --sort-by='.lastTimestamp' | grep <pod-name>
```

### 7.2. ImagePullBackOff

**Nguyên nhân:**
- Image không tồn tại
- Network issue
- Registry authentication

**Kiểm tra:**
```bash
kubectl describe pod <pod-name> -n default | grep -A 5 "Events"
```

**Giải pháp:**
- Kiểm tra image name có đúng không
- Thử pull image thủ công: `docker pull <image>`
- Nếu dùng minikube: `minikube ssh docker pull <image>`

### 7.3. PVC Pending

**Kiểm tra:**
```bash
kubectl get pvc -n default
kubectl describe pvc <pvc-name> -n default
```

**Nguyên nhân:**
- Không có StorageClass
- Node không có storage
- Quota hết

**Giải pháp:**
```bash
# Kiểm tra StorageClass
kubectl get storageclass

# Tạo StorageClass (nếu cần)
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
provisioner: k8s.io/minikube-hostpath
EOF
```

### 7.4. Controller Không Hoạt Động

**Kiểm tra controller pod:**
```bash
kubectl get pods -n notebook-controller-system
kubectl logs -n notebook-controller-system -l app=notebook-controller
```

**Kiểm tra RBAC:**
```bash
kubectl describe role notebook-controller -n notebook-controller-system
kubectl describe rolebinding notebook-controller -n notebook-controller-system
```

### 7.5. Notebook Không Ready

**Kiểm tra:**
```bash
kubectl get notebook <name> -n <namespace>
kubectl describe notebook <name> -n <namespace>
```

**Kiểm tra pod:**
```bash
kubectl get pods -n <namespace> -l notebook-name=<name>
kubectl describe pod <pod-name> -n <namespace>
```

### 7.6. Port-Forward Không Hoạt Động

**Kiểm tra:**
- Pod đã ready chưa
- Port có bị conflict không (dùng port khác)
- Firewall có block không

**Thử port khác:**
```bash
kubectl port-forward -n default $POD_NAME 8889:8888
```

### 7.7. 404 Not Found Khi Truy Cập

**Nguyên nhân:**
- URL path sai
- JupyterLab chưa start xong

**Giải pháp:**
- Dùng đúng path: `/notebook/{namespace}/{notebook-name}/lab`
- Đợi pod ready (kiểm tra logs)

---

## 8. Các Khái Niệm Quan Trọng

### 8.1. Custom Resource Definition (CRD)

**Định nghĩa:**
- Mở rộng Kubernetes API
- Cho phép tạo custom resources
- Notebook là một CRD

**Ví dụ:**
```yaml
apiVersion: kubeflow.org/v1
kind: Notebook  # Custom resource
metadata:
  name: my-notebook
spec:
  ...
```

**So sánh với built-in resources:**
- Built-in: Pod, Service, Deployment (có sẵn)
- Custom: Notebook (phải install CRD trước)

### 8.2. Controller Pattern

**Định nghĩa:**
- Process watch resources và reconcile
- Đảm bảo desired state = actual state

**Flow:**
```
1. User tạo Notebook resource
   ↓
2. Controller watch và detect
   ↓
3. Controller đọc spec.template
   ↓
4. Controller tạo Pod từ template
   ↓
5. Controller tạo Service
   ↓
6. Controller update status.ready
```

**Reconcile Loop:**
```go
for {
    desired := getNotebookSpec()      // Desired state
    actual := getPodStatus()           // Actual state
    
    if desired != actual {
        reconcile(desired, actual)     // Reconcile
    }
    
    sleep(interval)
}
```

### 8.3. Kustomize Overlays

**Định nghĩa:**
- Tool customize Kubernetes manifests
- Không cần fork hoặc duplicate manifests

**Cấu trúc:**
```
base/
├── kustomization.yaml
├── deployment.yaml
└── service.yaml

overlays/
├── production/
│   └── kustomization.yaml  # References base
└── development/
    └── kustomization.yaml   # References base
```

**Standalone Overlay:**
```yaml
resources:
- ../../base              # Kế thừa base
namespace: notebook-controller-system
configMapGenerator:
- name: config
  literals:
  - USE_ISTIO=false        # Override config
```

**Benefits:**
- Không duplicate manifests
- Dễ maintain
- Có thể combine nhiều overlays

### 8.4. Resources: Requests vs Limits

**Requests:**
- Minimum resources cần
- Kubernetes scheduler dùng để schedule
- Guaranteed resources

**Limits:**
- Maximum resources được dùng
- Kubelet enforce (kill nếu vượt)
- Prevent resource exhaustion

**Ví dụ:**
```yaml
resources:
  requests:
    cpu: "2.0"      # Minimum 2 CPUs
    memory: 4Gi      # Minimum 4GB RAM
  limits:
    cpu: "4.0"      # Maximum 4 CPUs
    memory: 8Gi     # Maximum 8GB RAM
```

**Chú ý:**
- Nếu không có requests → pod có thể bị schedule vào node không đủ resources
- Nếu không có limits → pod có thể dùng hết resources của node

### 8.5. PersistentVolumeClaim (PVC)

**Định nghĩa:**
- Request storage từ cluster
- Bind với PersistentVolume (PV)
- Dùng để mount vào pods

**Access Modes:**
- `ReadWriteOnce` (RWO): Chỉ 1 pod có thể mount
- `ReadWriteMany` (RWX): Nhiều pods có thể mount
- `ReadOnlyMany` (ROX): Nhiều pods read-only

**Ví dụ:**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: workspace
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
```

**Chú ý:**
- PVC phải `Bound` trước khi pod start
- Xóa PVC → mất dữ liệu (trừ khi dùng Retain policy)

### 8.6. Label Selectors

**Định nghĩa:**
- Dùng để filter và select resources
- Key-value pairs

**Ví dụ:**
```bash
# Select pods có label notebook-name=tensorflow-notebook
kubectl get pods -l notebook-name=tensorflow-notebook

# Select với nhiều labels
kubectl get pods -l app=notebook-controller,component=controller
```

**Chú ý:**
- Labels rất quan trọng để quản lý resources
- Controller tự động thêm labels vào pods

### 8.7. Port-Forward

**Định nghĩa:**
- Forward port từ local machine → pod
- Tạo tunnel qua API server

**Cách hoạt động:**
```
Local Machine → API Server → Pod
localhost:8888 → tunnel → pod:8888
```

**Chú ý:**
- Chỉ hoạt động khi process đang chạy
- Tạo connection trực tiếp, không qua Service
- Dùng cho development/testing, không production

### 8.8. Namespace Isolation

**Định nghĩa:**
- Namespace = virtual cluster
- Resources trong namespace này không thể access resources trong namespace khác (trừ khi có RBAC)

**Ví dụ:**
```bash
# Pod trong namespace default
kubectl get pods -n default

# Pod trong namespace khác
kubectl get pods -n my-namespace
```

**Chú ý:**
- Mỗi namespace có resources riêng
- Service trong namespace này không thể access service trong namespace khác (trừ khi dùng full DNS name)

---

## 9. Quick Reference

### 9.1. Checklist Deploy

```bash
# 1. Kiểm tra cluster
kubectl cluster-info
kubectl get nodes

# 2. Deploy Controller
cd manifests/apps/jupyter/notebook-controller/upstream
kustomize build overlays/standalone | kubectl apply -f -
kubectl wait --for condition=established --timeout=60s crd/notebooks.kubeflow.org
kubectl wait --for=condition=ready pod -l app=notebook-controller --timeout=180s -n notebook-controller-system

# 3. Tạo Notebook
kubectl apply -f examples/notebooks/tensorflow-notebook.yaml
kubectl wait --for=condition=ready notebook/tensorflow-notebook -n default --timeout=300s

# 4. Access Notebook
POD_NAME=$(kubectl get pods -n default -l notebook-name=tensorflow-notebook -o jsonpath='{.items[0].metadata.name}')
kubectl port-forward -n default $POD_NAME 8888:8888
```

### 9.2. Common Commands

| Mục đích | Lệnh |
|----------|------|
| Xem notebooks | `kubectl get notebooks -A` |
| Xem pods | `kubectl get pods -A` |
| Xem logs | `kubectl logs -n <ns> <pod>` |
| Describe resource | `kubectl describe <resource> <name> -n <ns>` |
| Delete resource | `kubectl delete <resource> <name> -n <ns>` |
| Port-forward | `kubectl port-forward -n <ns> <pod> <local>:<pod>` |
| Exec vào pod | `kubectl exec -it -n <ns> <pod> -- /bin/bash` |

### 9.3. Useful Aliases

Thêm vào `~/.bashrc` hoặc `~/.zshrc`:
```bash
alias k='kubectl'
alias kg='kubectl get'
alias kd='kubectl describe'
alias kl='kubectl logs'
alias ke='kubectl exec -it'
alias kgp='kubectl get pods'
alias kgn='kubectl get notebooks'
alias kga='kubectl get all'
```

---

## 10. Best Practices

### 10.1. Resource Management

- **Requests và Limits**: Luôn set cả requests và limits
- **Namespace**: Dùng namespace để isolate resources
- **Cleanup**: Xóa notebooks khi không dùng để giải phóng resources

### 10.2. Storage

- **PVC Size**: Estimate đúng size cần (không quá lớn, không quá nhỏ)
- **Backup**: Backup dữ liệu quan trọng (PVC có thể mất)
- **Cleanup**: Xóa PVC khi không cần (tiết kiệm storage)

### 10.3. Security

- **RBAC**: Giới hạn permissions cho users
- **Namespace**: Dùng namespace để isolate users/teams
- **Image**: Dùng image tags cụ thể thay vì `latest`

### 10.4. Monitoring

- **Status**: Thường xuyên kiểm tra notebook status
- **Logs**: Xem logs khi có vấn đề
- **Resources**: Monitor resource usage (CPU, memory, storage)

---

## Kết Luận

Tài liệu này cung cấp hướng dẫn chi tiết về:
- Từng câu lệnh kubectl
- Giải thích chi tiết cách hoạt động
- Các khái niệm quan trọng
- Troubleshooting

**Lưu ý:** 
- Tất cả lệnh đều có thể chạy trực tiếp, không cần scripts
- Scripts chỉ là wrapper để tự động hóa
- Hiểu rõ từng lệnh giúp debug và customize dễ hơn

---

**Tác giả:** Platform Lab Guide  
**Cập nhật:** 2024

