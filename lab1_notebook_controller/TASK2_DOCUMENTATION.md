# 📚 Tài Liệu Chi Tiết Task 2: Notebook Controller Standalone

Tài liệu này giải thích chi tiết từng dòng code, từng lệnh, và các khái niệm lý thuyết trong Task 2 - Deploy Notebook Controller Only.

---

## 📋 Mục Lục

1. [Tổng Quan Task 2](#tổng-quan-task-2)
2. [Script 06: Deploy Notebook Controller](#script-06-deploy-notebook-controller)
3. [Script 07: Create Notebook](#script-07-create-notebook)
4. [Script 08: Access Notebook](#script-08-access-notebook)
5. [Script 09: Check Notebook Status](#script-09-check-notebook-status)
6. [Khái Niệm Lý Thuyết](#khái-niệm-lý-thuyết)
7. [Notebook CRD và Spec](#notebook-crd-và-spec)
8. [Controller Pattern](#controller-pattern)
9. [So Sánh Task 1 vs Task 2](#so-sánh-task-1-vs-task-2)

---

## Tổng Quan Task 2

### Mục Đích

Task 2 tập trung vào việc deploy **chỉ Notebook Controller** mà không cần full Kubeflow platform. Điều này giúp:
- Hiểu cách deploy component độc lập
- Giảm complexity và resource usage
- Học về Controller pattern trong Kubernetes
- Hiểu CRD (Custom Resource Definition)

### Architecture

```
┌─────────────────────────────────────────┐
│     Notebook Controller System           │
│  ┌───────────────────────────────────┐  │
│  │  Notebook CRD                     │  │
│  │  (notebooks.kubeflow.org)         │  │
│  └───────────────────────────────────┘  │
│              │                            │
│              ▼                            │
│  ┌───────────────────────────────────┐  │
│  │  Controller Pod                   │  │
│  │  - Watches Notebook resources     │  │
│  │  - Creates Pods/Services          │  │
│  │  - Updates status                 │  │
│  └───────────────────────────────────┘  │
│              │                            │
│              ▼                            │
│  ┌───────────────────────────────────┐  │
│  │  Notebook Resources               │  │
│  │  ├── Pod (Jupyter)                 │  │
│  │  ├── Service                       │  │
│  │  └── PVC (workspace)               │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

---

## Script 06: Deploy Notebook Controller

**File:** `scripts/06_deploy_notebook_controller.sh`

**Mục đích:** Deploy chỉ Notebook Controller với standalone overlay (không cần Istio, không cần Kubeflow).

### Phân Tích Chi Tiết

#### 1. Configuration

```bash
MANIFESTS_DIR="./manifests"
NOTEBOOK_CONTROLLER_PATH="$MANIFESTS_DIR/apps/jupyter/notebook-controller/upstream"
```

**Giải thích:**
- `MANIFESTS_DIR`: Thư mục chứa Kubeflow manifests (đã clone từ Task 1)
- `NOTEBOOK_CONTROLLER_PATH`: Path đến notebook-controller manifests
- `upstream/`: Chứa source manifests từ upstream repository

**Cấu trúc manifests:**
```
manifests/
└── apps/
    └── jupyter/
        └── notebook-controller/
            └── upstream/
                ├── base/              # Base kustomization
                ├── overlays/
                │   ├── kubeflow/      # Overlay cho full Kubeflow
                │   └── standalone/    # Overlay cho standalone (Task 2)
                ├── crd/               # CRD definitions
                ├── rbac/              # RBAC resources
                └── manager/           # Controller deployment
```

#### 2. Check Manifests Directory

```bash
if [ ! -d "$MANIFESTS_DIR" ]; then
    print_error "Manifests directory not found!"
    echo "Please run ./scripts/02_deploy_kubeflow.sh first to clone manifests,"
    echo "or manually clone: git clone https://github.com/kubeflow/manifests.git"
    exit 1
fi
```

**Giải thích:**
- `[ ! -d "$MANIFESTS_DIR" ]`: Kiểm tra thư mục không tồn tại
- `-d`: Test nếu là directory
- Nếu không có → hướng dẫn clone manifests

**Tại sao cần manifests?**
- Chứa tất cả Kubernetes manifests cho Notebook Controller
- Có thể clone riêng hoặc dùng từ Task 1

#### 3. Check Cluster Connection

```bash
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi
```

**Giải thích:**
- `kubectl cluster-info`: Kiểm tra kết nối đến cluster
- `!`: Negate (nếu không kết nối được)
- Phải có cluster running trước khi deploy

#### 4. Deploy với Standalone Overlay

```bash
cd "$NOTEBOOK_CONTROLLER_PATH"
kustomize build overlays/standalone | kubectl apply -f -
```

**Giải thích từng phần:**

1. **`cd "$NOTEBOOK_CONTROLLER_PATH"`**:
   - Chuyển vào thư mục notebook-controller
   - Cần thiết vì kustomize build relative paths

2. **`kustomize build overlays/standalone`**:
   - Build manifests từ standalone overlay
   - Standalone overlay không cần Istio, không cần Kubeflow dependencies

3. **`| kubectl apply -f -`**:
   - Pipe output sang kubectl apply
   - `-f -`: Đọc từ stdin

**Standalone Overlay:**

Xem `overlays/standalone/kustomization.yaml`:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ../../base
namespace: notebook-controller-system
configMapGenerator:
- name: config
  behavior: merge
  literals:
  - USE_ISTIO=false
```

**Giải thích:**
- `resources: - ../../base`: Kế thừa từ base
- `namespace: notebook-controller-system`: Set namespace
- `USE_ISTIO=false`: Tắt Istio integration (không cần service mesh)

**So sánh với Kubeflow overlay:**
- **Kubeflow overlay**: Cần Istio, KFAM (Kubeflow Access Management)
- **Standalone overlay**: Không cần dependencies, minimal setup

#### 5. Wait for CRD

```bash
kubectl wait --for condition=established --timeout=60s crd/notebooks.kubeflow.org 2>/dev/null || true
```

**Giải thích từng phần:**

1. **`kubectl wait`**: Đợi resource đạt condition
2. **`--for condition=established`**: CRD condition khi đã được API server accept
3. **`crd/notebooks.kubeflow.org`**: CRD name
4. **`--timeout=60s`**: Timeout sau 60 giây
5. **`2>/dev/null`**: Ẩn lỗi
6. **`|| true`**: Nếu fail, vẫn tiếp tục (không dừng script)

**CRD Established Condition:**
- CRD phải được established trước khi tạo custom resources
- Nếu không established → tạo Notebook sẽ fail

#### 6. Wait for Controller Pod

```bash
kubectl wait --for=condition=ready pod -l app=notebook-controller --timeout=180s -n notebook-controller-system 2>/dev/null || true
```

**Giải thích:**
- `--for=condition=ready`: Đợi pod ready (containers started)
- `-l app=notebook-controller`: Label selector
- `-n notebook-controller-system`: Namespace

**Pod Ready Condition:**
- Tất cả containers đã start
- Readiness probe passed (nếu có)
- Pod có thể nhận traffic

#### 7. Verify Deployment

```bash
CONTROLLER_READY=$(kubectl get pods -n notebook-controller-system -l app=notebook-controller --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
CRD_EXISTS=$(kubectl get crd notebooks.kubeflow.org 2>/dev/null | wc -l)
```

**Giải thích:**
- `--field-selector=status.phase=Running`: Chỉ lấy pods đang Running
- `--no-headers`: Bỏ header line
- `wc -l`: Đếm số dòng (số pods)
- `kubectl get crd`: Kiểm tra CRD tồn tại

**Verification Logic:**
- Nếu `CONTROLLER_READY > 0` và `CRD_EXISTS > 0` → deployment thành công
- Nếu không → in lỗi và hướng dẫn check logs

---

## Script 07: Create Notebook

**File:** `scripts/07_create_notebook.sh`

**Mục đích:** Tạo Notebook resource từ YAML (interactive hoặc từ file).

### Phân Tích Chi Tiết

#### 1. Check CRD Exists

```bash
if ! kubectl get crd notebooks.kubeflow.org &> /dev/null; then
    print_error "Notebook CRD not found!"
    echo "Please deploy Notebook Controller first:"
    echo "  ./scripts/06_deploy_notebook_controller.sh"
    exit 1
fi
```

**Giải thích:**
- Phải có CRD trước khi tạo Notebook resources
- Nếu không có → hướng dẫn deploy controller

#### 2. Get Namespace

```bash
read -p "Enter namespace for notebook (default: default): " NOTEBOOK_NAMESPACE
NOTEBOOK_NAMESPACE=${NOTEBOOK_NAMESPACE:-default}
```

**Giải thích:**
- `read -p`: Prompt user và đọc input
- `${NOTEBOOK_NAMESPACE:-default}`: Nếu biến rỗng/null, dùng "default"
- **Parameter expansion**: `${var:-default}` = use default if empty

#### 3. Create Namespace if Needed

```bash
if ! kubectl get namespace "$NOTEBOOK_NAMESPACE" &> /dev/null; then
    print_info "Creating namespace: $NOTEBOOK_NAMESPACE"
    kubectl create namespace "$NOTEBOOK_NAMESPACE"
    print_success "Namespace created"
fi
```

**Giải thích:**
- Kiểm tra namespace tồn tại
- Nếu không → tạo mới
- Namespace cần thiết để isolate resources

#### 4. Choose Notebook Type

```bash
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
        ;;
esac
```

**Giải thích:**
- `case ... in`: Switch statement trong bash
- Mỗi option set các biến: name, image, resources
- GPU notebook có thêm `GPU="1"`

**Notebook Images:**
- `jupyter-scipy`: Basic Jupyter với SciPy stack
- `jupyter-tensorflow-full`: Jupyter + TensorFlow đầy đủ
- `jupyter-tensorflow-cuda-full`: Jupyter + TensorFlow + CUDA (GPU)

#### 5. Create Temporary YAML

```bash
TEMP_YAML=$(mktemp)
```

**Giải thích:**
- `mktemp`: Tạo temporary file
- Trả về path đến file
- File tự động có unique name

**Tại sao dùng temp file?**
- Tạo YAML động dựa trên user input
- Không cần lưu file vĩnh viễn
- Tự động cleanup sau khi dùng

#### 6. Generate YAML cho CPU Notebook

```bash
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
EOF
```

**Giải thích từng phần:**

1. **`cat > "$TEMP_YAML" <<EOF`**:
   - Heredoc syntax
   - `<<EOF`: Bắt đầu heredoc
   - `EOF`: Kết thúc heredoc
   - `> "$TEMP_YAML"`: Write vào file

2. **`apiVersion: kubeflow.org/v1`**:
   - API version của Notebook CRD
   - `v1`: Stable version

3. **`kind: Notebook`**:
   - Resource type (Custom Resource)

4. **`spec.template.spec`**:
   - Template cho Pod spec
   - Controller sẽ dùng để tạo Pod

5. **`resources.requests` và `resources.limits`**:
   - **requests**: Minimum resources cần
   - **limits**: Maximum resources được dùng
   - Kubernetes scheduler dùng requests để schedule
   - Kubelet enforce limits

**Resource Units:**
- CPU: `"1.0"` = 1 core, `"0.5"` = 0.5 core
- Memory: `"2Gi"` = 2 GiB, `"512Mi"` = 512 MiB

#### 7. Generate YAML cho GPU Notebook

```bash
if [ "$NOTEBOOK_TYPE" = "3" ] && [ -n "$GPU" ]; then
    cat > "$TEMP_YAML" <<EOF
...
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
EOF
fi
```

**Giải thích:**

1. **`env: - name: NVIDIA_VISIBLE_DEVICES`**:
   - Environment variable cho NVIDIA GPU
   - `"all"`: Expose tất cả GPUs

2. **`nvidia.com/gpu: ${GPU}`**:
   - GPU resource request/limit
   - `nvidia.com/gpu`: Extended resource type
   - Cần NVIDIA device plugin để hoạt động

**GPU Requirements:**
- Cluster phải có GPU nodes
- NVIDIA device plugin phải được cài
- Node phải có label: `accelerator=nvidia-tesla-*`

#### 8. Add Workspace Volume

```bash
cat >> "$TEMP_YAML" <<EOF
  volumes:
  - name: workspace
    persistentVolumeClaim:
      claimName: ${NOTEBOOK_NAME}-workspace
EOF
```

**Giải thích:**
- `cat >>`: Append vào file (không overwrite)
- `volumes`: Pod volumes
- `persistentVolumeClaim`: Mount PVC vào pod
- `claimName`: Tên PVC (sẽ tạo sau)

**Tại sao cần workspace volume?**
- Persist data giữa các lần restart
- Lưu notebooks, models, data
- Share data giữa containers (nếu có)

#### 9. Create PVC

```bash
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
```

**Giải thích:**

1. **`PersistentVolumeClaim`**:
   - Request storage từ cluster
   - PVC → PV (Persistent Volume) → Storage

2. **`accessModes: ReadWriteOnce`**:
   - Chỉ một pod có thể mount
   - Phù hợp cho single notebook

3. **`storage: 10Gi`**:
   - Request 10 GiB storage
   - Cluster sẽ provision PV

**PVC Lifecycle:**
1. User tạo PVC
2. Kubernetes tìm PV phù hợp
3. Bind PVC với PV
4. Pod mount PVC
5. Data persist ngay cả khi pod delete

#### 10. Apply Notebook

```bash
kubectl apply -f "$TEMP_YAML"
```

**Giải thích:**
- Apply Notebook resource
- Controller sẽ detect và tạo Pod/Service

**What happens next:**
1. Notebook resource created
2. Controller watches và detect
3. Controller tạo Pod từ `spec.template`
4. Controller tạo Service để expose
5. Controller update `status.ready`

#### 11. Wait for Ready

```bash
for i in {1..30}; do
    STATUS=$(kubectl get notebook "$NOTEBOOK_NAME" -n "$NOTEBOOK_NAMESPACE" -o jsonpath='{.status.ready}' 2>/dev/null || echo "false")
    if [ "$STATUS" = "true" ]; then
        print_success "Notebook is ready! 🎉"
        break
    fi
    echo -n "."
    sleep 5
done
```

**Giải thích:**

1. **`for i in {1..30}`**:
   - Loop 30 lần
   - `{1..30}`: Brace expansion (1, 2, 3, ..., 30)

2. **`kubectl get notebook ... -o jsonpath='{.status.ready}'`**:
   - Lấy field `status.ready` từ Notebook
   - JSONPath expression
   - `.status.ready`: Path trong JSON

3. **`echo -n "."`**:
   - In dấu chấm không xuống dòng
   - Progress indicator

4. **`sleep 5`**:
   - Đợi 5 giây trước khi check lại

**Notebook Status:**
- `status.ready = true`: Pod đã start và ready
- `status.ready = false`: Đang khởi tạo hoặc có lỗi

---

## Script 08: Access Notebook

**File:** `scripts/08_access_notebook.sh`

**Mục đích:** Setup port-forward để truy cập Notebook qua browser.

### Phân Tích Chi Tiết

#### 1. List Available Notebooks

```bash
NOTEBOOKS=$(kubectl get notebooks -A --no-headers 2>/dev/null | awk '{print $2 " -n " $1}')
```

**Giải thích:**
- `kubectl get notebooks -A`: Lấy notebooks từ tất cả namespaces
- `--no-headers`: Bỏ header line
- `awk '{print $2 " -n " $1}'`: Format output (name -n namespace)

**Output format:**
```
notebook-name -n default
another-notebook -n my-namespace
```

#### 2. Get Notebook Name and Namespace

```bash
if [ -z "$1" ] || [ -z "$2" ]; then
    read -p "Enter notebook name: " NOTEBOOK_NAME
    read -p "Enter namespace (default: default): " NOTEBOOK_NAMESPACE
    NOTEBOOK_NAMESPACE=${NOTEBOOK_NAMESPACE:-default}
else
    NOTEBOOK_NAME=$1
    NOTEBOOK_NAMESPACE=$2
fi
```

**Giải thích:**
- `[ -z "$1" ]`: Kiểm tra tham số đầu tiên rỗng
- Nếu không có tham số → prompt user
- Nếu có tham số → dùng tham số (script có thể gọi với args)

**Usage:**
```bash
# Interactive
./scripts/08_access_notebook.sh

# With arguments
./scripts/08_access_notebook.sh my-notebook default
```

#### 3. Check Notebook Ready

```bash
READY=$(kubectl get notebook "$NOTEBOOK_NAME" -n "$NOTEBOOK_NAMESPACE" -o jsonpath='{.status.ready}' 2>/dev/null || echo "false")
if [ "$READY" != "true" ]; then
    print_error "Notebook is not ready yet!"
    exit 1
fi
```

**Giải thích:**
- Kiểm tra `status.ready`
- Nếu không ready → in lỗi và exit
- Phải đợi notebook ready trước khi access

#### 4. Get Pod Name

```bash
POD_NAME=$(kubectl get pods -n "$NOTEBOOK_NAMESPACE" -l notebook-name="$NOTEBOOK_NAME" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
```

**Giải thích:**
- `-l notebook-name="$NOTEBOOK_NAME"`: Label selector
- Controller tự động thêm label `notebook-name` vào pod
- `{.items[0].metadata.name}`: Lấy tên pod đầu tiên

**Label Selector:**
- Controller tạo pod với label: `notebook-name=<notebook-name>`
- Dùng để query pods của một notebook

#### 5. Get Access Token

```bash
TOKEN=$(kubectl exec -n "$NOTEBOOK_NAMESPACE" "$POD_NAME" -- jupyter notebook list 2>/dev/null | grep -oP 'token=\K[^\s]+' | head -1 || echo "")
```

**Giải thích từng phần:**

1. **`kubectl exec`**:
   - Execute command trong pod
   - `--`: Separator (args sau `--` là command)

2. **`jupyter notebook list`**:
   - List running Jupyter servers
   - Output: `http://localhost:8888/?token=abc123...`

3. **`grep -oP 'token=\K[^\s]+'`**:
   - `-o`: Chỉ in phần match
   - `-P`: Perl regex
   - `token=\K`: Match "token=" nhưng không include trong output
   - `[^\s]+`: Match một hoặc nhiều non-whitespace chars

4. **`head -1`**: Lấy dòng đầu tiên

**Token Purpose:**
- Jupyter yêu cầu token để authenticate
- Token được generate tự động khi start
- Có thể disable (không khuyến nghị)

#### 6. Port Forward

```bash
kubectl port-forward -n "$NOTEBOOK_NAMESPACE" "$POD_NAME" "$PORT:8888"
```

**Giải thích:**
- `kubectl port-forward`: Forward port từ pod đến local
- `$PORT:8888`: Local port → Pod port
- Default: `8888:8888` (Jupyter default port)

**How Port Forward Works:**
1. kubectl tạo tunnel đến API server
2. API server forward đến pod
3. Traffic từ `localhost:$PORT` → pod port 8888
4. Blocking command (chạy đến khi Ctrl+C)

**Access:**
- URL: `http://localhost:$PORT`
- Với token: `http://localhost:$PORT/?token=$TOKEN`

---

## Script 09: Check Notebook Status

**File:** `scripts/09_check_notebook_status.sh`

**Mục đích:** Kiểm tra trạng thái của tất cả Notebooks.

### Phân Tích Chi Tiết

#### 1. Get All Notebooks

```bash
NOTEBOOKS=$(kubectl get notebooks -A --no-headers 2>/dev/null)
```

**Giải thích:**
- Lấy tất cả notebooks từ tất cả namespaces
- Lưu vào biến để process sau

#### 2. Parse Notebook Information

```bash
while IFS= read -r line; do
    if [ -z "$line" ]; then
        continue
    fi
    
    NAMESPACE=$(echo "$line" | awk '{print $1}')
    NAME=$(echo "$line" | awk '{print $2}')
    READY=$(echo "$line" | awk '{print $3}')
    AGE=$(echo "$line" | awk '{print $4}')
done <<< "$NOTEBOOKS"
```

**Giải thích:**

1. **`while IFS= read -r line`**:
   - Loop qua từng dòng
   - `IFS=`: Set Internal Field Separator rỗng (preserve spaces)
   - `-r`: Raw mode (không interpret backslashes)

2. **`<<< "$NOTEBOOKS"`**:
   - Here-string: Feed string vào stdin
   - Tương đương `echo "$NOTEBOOKS" | while ...`

3. **`awk '{print $1}'`**:
   - Print field đầu tiên (namespace)
   - Fields separated by whitespace

**Input format:**
```
default    my-notebook    True    5m
my-ns      another        False   2m
```

#### 3. Get Pod Status

```bash
POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l notebook-name="$NAME" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
POD_STATUS=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
```

**Giải thích:**
- Lấy pod name từ label selector
- Lấy pod phase (Running, Pending, Failed, etc.)

**Pod Phases:**
- `Pending`: Đang chờ schedule
- `Running`: Đang chạy
- `Succeeded`: Completed successfully
- `Failed`: Có lỗi
- `Unknown`: Không xác định được

#### 4. Get Resource Usage

```bash
if kubectl top pod "$POD_NAME" -n "$NAMESPACE" &> /dev/null; then
    echo "Resource Usage:"
    kubectl top pod "$POD_NAME" -n "$NAMESPACE"
fi
```

**Giải thích:**
- `kubectl top`: Hiển thị resource usage
- Cần metrics-server hoặc cAdvisor
- Nếu không có → skip (không fail)

**Metrics Server:**
- Collect resource usage từ nodes
- Expose qua Metrics API
- Cần cho `kubectl top` và HPA

#### 5. Get Events

```bash
kubectl get events -n "$NAMESPACE" --field-selector involvedObject.name="$NAME" --sort-by='.lastTimestamp' | tail -3
```

**Giải thích:**
- `get events`: Lấy events liên quan
- `--field-selector`: Filter theo object name
- `--sort-by='.lastTimestamp'`: Sort theo thời gian
- `tail -3`: Lấy 3 events gần nhất

**Events:**
- Ghi lại các thay đổi và actions
- Useful để debug issues
- Ví dụ: Pod scheduled, Image pulled, Container started

#### 6. Summary Statistics

```bash
TOTAL=$(echo "$NOTEBOOKS" | wc -l)
READY_COUNT=$(echo "$NOTEBOOKS" | grep -c "True" || echo "0")
```

**Giải thích:**
- `wc -l`: Đếm số dòng (tổng notebooks)
- `grep -c "True"`: Đếm số dòng chứa "True" (ready notebooks)
- `|| echo "0"`: Nếu không tìm thấy, return 0

---

## Khái Niệm Lý Thuyết

### 1. Custom Resource Definition (CRD)

**CRD** là cách mở rộng Kubernetes API với custom resources.

**Ví dụ Notebook CRD:**
```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: notebooks.kubeflow.org
spec:
  group: kubeflow.org
  versions:
    - name: v1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                template:
                  type: object
  scope: Namespaced
  names:
    plural: notebooks
    singular: notebook
    kind: Notebook
```

**Giải thích:**
- `group`: API group (`kubeflow.org`)
- `versions`: API versions
- `scope`: Namespaced (trong namespace) hoặc Cluster (global)
- `names`: Tên resource (plural, singular, kind)

**Sau khi tạo CRD:**
- Có thể tạo Notebook resources
- `kubectl get notebooks` hoạt động
- API server validate schema

### 2. Controller Pattern

**Controller** là process watch resources và reconcile desired state.

**Notebook Controller Flow:**
```
1. User tạo Notebook resource
   ↓
2. Controller watch và detect
   ↓
3. Controller đọc spec.template
   ↓
4. Controller tạo Pod từ template
   ↓
5. Controller tạo Service để expose
   ↓
6. Controller update status.ready
```

**Reconcile Loop:**
```go
for {
    // 1. Get desired state (Notebook spec)
    desired := getNotebookSpec()
    
    // 2. Get actual state (Pod status)
    actual := getPodStatus()
    
    // 3. Compare and reconcile
    if desired != actual {
        reconcile(desired, actual)
    }
    
    // 4. Wait
    sleep(interval)
}
```

**Controller Responsibilities:**
- Watch Notebook resources
- Create/Update/Delete Pods
- Create/Update/Delete Services
- Update Notebook status
- Handle errors và retries

### 3. Kustomize Overlays

**Kustomize** cho phép customize manifests mà không cần fork.

**Base Structure:**
```
base/
├── kustomization.yaml
├── deployment.yaml
└── service.yaml
```

**Overlay Structure:**
```
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
- Không cần duplicate manifests
- Dễ maintain
- Có thể combine nhiều overlays

### 4. Resource Requests và Limits

**Requests:**
- Minimum resources cần
- Kubernetes scheduler dùng để schedule
- Guaranteed resources

**Limits:**
- Maximum resources được dùng
- Kubelet enforce (kill nếu vượt)
- Prevent resource exhaustion

**Example:**
```yaml
resources:
  requests:
    cpu: "1.0"      # Cần ít nhất 1 CPU
    memory: 2Gi     # Cần ít nhất 2 GiB
  limits:
    cpu: "2.0"      # Tối đa 2 CPU
    memory: 4Gi     # Tối đa 4 GiB
```

**Quality of Service (QoS):**
- **Guaranteed**: requests = limits
- **Burstable**: requests < limits
- **BestEffort**: No requests/limits

### 5. Persistent Volumes

**PVC (PersistentVolumeClaim):**
- Request storage từ cluster
- User không cần biết storage backend

**PV (PersistentVolume):**
- Actual storage resource
- Provisioned bởi admin hoặc dynamically

**Storage Class:**
- Template để provision PVs
- Define provisioner, parameters

**Lifecycle:**
```
User creates PVC
    ↓
Kubernetes finds matching PV
    ↓
Bind PVC to PV
    ↓
Pod mounts PVC
    ↓
Data persists
```

### 6. Label Selectors

**Labels** là key-value pairs để organize resources.

**Notebook Controller Labels:**
- `app: notebook-controller` (controller pod)
- `notebook-name: <name>` (notebook pods)

**Selectors:**
```bash
# Select pods của một notebook
kubectl get pods -l notebook-name=my-notebook

# Select controller pods
kubectl get pods -l app=notebook-controller
```

**Benefits:**
- Organize resources
- Query và filter
- Service selectors

---

## Notebook CRD và Spec

### Notebook Spec Structure

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
        image: jupyter/scipy-notebook:latest
        resources:
          requests:
            cpu: "1.0"
            memory: 2Gi
          limits:
            cpu: "2.0"
            memory: 4Gi
        env:
        - name: JUPYTER_ENABLE_LAB
          value: "yes"
  volumes:
  - name: workspace
    persistentVolumeClaim:
      claimName: my-notebook-workspace
```

**Key Fields:**
- `spec.template.spec`: Pod template (giống Pod spec)
- `spec.volumes`: Volumes để mount
- `metadata`: Name, namespace, labels

### Controller Behavior

**Khi tạo Notebook:**
1. Controller detect Notebook resource
2. Tạo Pod từ `spec.template.spec`
3. Tạo Service với port 8888
4. Add label `notebook-name=<name>`
5. Update `status.ready = true` khi pod ready

**Khi xóa Notebook:**
1. Controller detect deletion
2. Xóa Pod và Service
3. **PVC không tự động xóa** (bảo vệ data)

### Status Fields

```yaml
status:
  ready: true
  conditions:
  - type: Ready
    status: "True"
    lastTransitionTime: "2024-01-01T00:00:00Z"
```

**Status.ready:**
- `true`: Pod ready và accessible
- `false`: Đang khởi tạo hoặc có lỗi

---

## So Sánh Task 1 vs Task 2

### Component Comparison

| Component | Task 1 (Full) | Task 2 (Standalone) |
|-----------|---------------|---------------------|
| **Istio** | ✅ Required | ❌ Not needed |
| **Cert Manager** | ✅ Required | ❌ Not needed |
| **Dex** | ✅ Required | ❌ Not needed |
| **Knative** | ✅ Required | ❌ Not needed |
| **Notebook Controller** | ✅ Included | ✅ Only this |
| **Jupyter Web App** | ✅ Included | ❌ Not needed |
| **Namespaces** | 7+ | 1 |
| **Pods** | ~100+ | ~2-3 |

### Resource Usage

**Task 1:**
- CPU: ~20+ cores
- Memory: ~40+ GB
- Storage: ~50+ GB

**Task 2:**
- CPU: ~0.5 cores
- Memory: ~1 GB
- Storage: ~5 GB

### Use Cases

**Task 1 (Full Kubeflow):**
- Production ML platform
- Multiple teams
- Need pipelines, serving, etc.
- Complex workflows

**Task 2 (Standalone):**
- Development/testing
- Single team
- Chỉ cần Jupyter Notebooks
- Simple use case

### Trade-offs

**Full Kubeflow:**
- ✅ Full features
- ✅ Multi-user support
- ✅ Advanced workflows
- ❌ High resource usage
- ❌ Complex setup
- ❌ Longer deployment time

**Standalone:**
- ✅ Low resource usage
- ✅ Simple setup
- ✅ Fast deployment
- ❌ Limited features
- ❌ No web UI
- ❌ Manual management

---

## Best Practices

### 1. Resource Sizing

**CPU:**
- Development: 0.5-1.0 cores
- Training: 2-4 cores
- Production: 4+ cores

**Memory:**
- Development: 2-4 GiB
- Training: 8-16 GiB
- Production: 16+ GiB

**Storage:**
- Development: 10 GiB
- Training: 50-100 GiB
- Production: 100+ GiB

### 2. Namespace Organization

**Recommendation:**
- Mỗi user/team một namespace
- Isolate resources
- Easy cleanup

```bash
# User namespace
kubectl create namespace user-alice
kubectl create namespace user-bob
```

### 3. Image Selection

**Choose based on needs:**
- `jupyter-scipy`: Basic data science
- `jupyter-tensorflow-full`: ML với TensorFlow
- `jupyter-pytorch-full`: ML với PyTorch
- `jupyter-tensorflow-cuda-full`: GPU training

### 4. Security

**Recommendations:**
- Use RBAC để limit access
- Enable token authentication
- Limit resource usage
- Regular cleanup unused notebooks

### 5. Monitoring

**Monitor:**
- Notebook status
- Resource usage
- Pod health
- Storage usage

**Tools:**
- `kubectl get notebooks`
- `kubectl top pods`
- Prometheus (nếu có)

---

## Troubleshooting Guide

### Notebook không start

**Check:**
```bash
# Pod status
kubectl get pods -l notebook-name=<name>

# Pod logs
kubectl logs -l notebook-name=<name>

# Events
kubectl describe notebook <name>
```

**Common issues:**
- Image pull errors → Check image name
- Resource limits → Increase resources
- PVC not bound → Check storage class

### Controller không hoạt động

**Check:**
```bash
# Controller pod
kubectl get pods -n notebook-controller-system

# Controller logs
kubectl logs -n notebook-controller-system -l app=notebook-controller
```

**Common issues:**
- RBAC permissions → Check roles
- CRD not established → Wait longer
- Image pull errors → Check image

### Port-forward không hoạt động

**Check:**
```bash
# Pod status
kubectl get pods -l notebook-name=<name>

# Service
kubectl get svc -l notebook-name=<name>
```

**Common issues:**
- Pod not ready → Wait for ready
- Port conflict → Use different port
- Network issues → Check cluster network

---

## Tóm Tắt

### Script 06: Deploy Controller
- Deploy Notebook Controller với standalone overlay
- Tạo CRD, RBAC, Controller pod
- Verify deployment

### Script 07: Create Notebook
- Tạo Notebook resource từ YAML
- Support CPU và GPU notebooks
- Tự động tạo PVC

### Script 08: Access Notebook
- Setup port-forward
- Get access token
- Access qua browser

### Script 09: Check Status
- List tất cả notebooks
- Chi tiết từng notebook
- Resource usage và events

### Key Concepts
- **CRD**: Custom Resource Definition
- **Controller**: Watch và reconcile resources
- **Kustomize**: Customize manifests
- **PVC**: Persistent storage
- **Labels**: Organize resources

---

**Tác giả:** Generated for Platform Lab  
**Ngày:** 2024  
**Version:** 1.0


