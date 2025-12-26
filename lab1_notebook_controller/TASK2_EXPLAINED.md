# 📚 Giải Thích Chi Tiết Task 2: Notebook Controller Standalone

Tài liệu này giải thích **từng dòng code**, **từng lệnh**, và **ý nghĩa** của mọi thứ trong Task 2.

---

## 📋 Mục Lục

1. [Tổng Quan Task 2](#tổng-quan-task-2)
2. [Script 06: Deploy Notebook Controller - Giải Thích Từng Dòng](#script-06-deploy-notebook-controller)
3. [Script 07: Create Notebook - Giải Thích Từng Dòng](#script-07-create-notebook)
4. [Script 08: Access Notebook - Giải Thích Từng Dòng](#script-08-access-notebook)
5. [Script 09: Check Status - Giải Thích Từng Dòng](#script-09-check-status)
6. [Notebook YAML Examples - Giải Thích Chi Tiết](#notebook-yaml-examples)
7. [Khái Niệm Lý Thuyết](#khái-niệm-lý-thuyết)
8. [So Sánh Task 1 vs Task 2](#so-sánh-task-1-vs-task-2)

---

## Tổng Quan Task 2

### Mục Đích

Task 2 deploy **chỉ Notebook Controller** mà không cần full Kubeflow. Điều này giúp:
- ✅ Hiểu cách deploy component độc lập
- ✅ Giảm complexity (từ 18 components → 1 component)
- ✅ Giảm resource usage (từ ~100 pods → 2-3 pods)
- ✅ Học Controller pattern trong Kubernetes

### Architecture Flow

```
User chạy script 06
    ↓
Deploy Notebook Controller
    ├── CRD: notebooks.kubeflow.org
    ├── RBAC: Roles, RoleBindings
    └── Controller Pod
    ↓
User chạy script 07
    ↓
Tạo Notebook Resource
    ↓
Controller detect và tạo:
    ├── Pod (Jupyter)
    ├── Service
    └── Mount PVC
    ↓
User chạy script 08
    ↓
Port-forward → Access Notebook
```

---

## Script 06: Deploy Notebook Controller

**File:** `scripts/06_deploy_notebook_controller.sh`

### Dòng 1-6: Shebang và Setup

```bash
#!/bin/bash
# Script: Deploy Notebook Controller Only
# Description: Deploy chỉ Notebook Controller (không cần full Kubeflow)
set -e
```

**Giải thích:**
- `#!/bin/bash`: Shebang - chỉ định shell interpreter
- `set -e`: **Exit on error** - script sẽ dừng ngay khi có lệnh fail
  - Ví dụ: Nếu `kubectl apply` fail → script dừng, không chạy tiếp
  - Giúp tránh lỗi cascade (lỗi dây chuyền)

### Dòng 8-11: Header

```bash
echo "========================================"
echo "Deploying Notebook Controller (Standalone)"
echo "========================================"
echo ""
```

**Giải thích:**
- In header để user biết script đang làm gì
- `echo ""`: In dòng trống để dễ đọc

### Dòng 13-17: Color Definitions

```bash
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
```

**Giải thích:**
- ANSI color codes cho terminal
- `\033[0;32m`: Green color
- `\033[1;33m`: Bold yellow
- `\033[0;31m`: Red color
- `\033[0m`: Reset color (No Color)
- Dùng để in messages có màu (dễ nhìn hơn)

### Dòng 19-21: Print Functions

```bash
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_info() { echo -e "${YELLOW}➜ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
```

**Giải thích:**
- **Function definitions** trong bash
- `$1`: Tham số đầu tiên (message)
- `-e`: Enable escape sequences (để `\033` hoạt động)
- `✓`, `➜`, `✗`: Unicode symbols (checkmark, arrow, cross)
- **Usage:** `print_success "Done!"` → in "✓ Done!" màu xanh

### Dòng 23-25: Configuration

```bash
MANIFESTS_DIR="./manifests"
NOTEBOOK_CONTROLLER_PATH="$MANIFESTS_DIR/apps/jupyter/notebook-controller/upstream"
```

**Giải thích:**
- `MANIFESTS_DIR`: Thư mục chứa Kubeflow manifests
  - `./manifests`: Relative path từ script location
- `NOTEBOOK_CONTROLLER_PATH`: Path đến notebook-controller manifests
  - `$MANIFESTS_DIR`: Variable expansion
  - Cấu trúc: `manifests/apps/jupyter/notebook-controller/upstream/`

**Tại sao cần manifests?**
- Chứa tất cả Kubernetes YAML files
- Có thể clone từ GitHub hoặc dùng từ Task 1

### Dòng 27-33: Check Manifests Directory

```bash
if [ ! -d "$MANIFESTS_DIR" ]; then
    print_error "Manifests directory not found!"
    echo "Please run ./scripts/02_deploy_kubeflow.sh first to clone manifests,"
    echo "or manually clone: git clone https://github.com/kubeflow/manifests.git"
    exit 1
fi
```

**Giải thích từng phần:**

1. **`[ ! -d "$MANIFESTS_DIR" ]`**:
   - `[ ]`: Test command trong bash
   - `-d`: Test nếu là directory
   - `!`: Negate (NOT)
   - Nghĩa: "Nếu `$MANIFESTS_DIR` KHÔNG phải là directory"

2. **`print_error "..."`**:
   - In error message màu đỏ

3. **`exit 1`**:
   - Exit script với error code 1
   - `0` = success, `1+` = error

**Flow:**
- Nếu manifests không tồn tại → in lỗi → exit
- Nếu tồn tại → tiếp tục

### Dòng 35-40: Check Notebook Controller Path

```bash
if [ ! -d "$NOTEBOOK_CONTROLLER_PATH" ]; then
    print_error "Notebook controller manifests not found!"
    echo "Expected path: $NOTEBOOK_CONTROLLER_PATH"
    exit 1
fi
```

**Giải thích:**
- Kiểm tra path cụ thể đến notebook-controller
- Nếu không có → exit với error
- Đảm bảo manifests đã được clone đúng

### Dòng 42-49: Check Cluster Connection

```bash
print_info "Checking cluster connection..."
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    echo "Please ensure your cluster is running and kubeconfig is properly configured"
    exit 1
fi
print_success "Cluster connected"
```

**Giải thích từng phần:**

1. **`kubectl cluster-info`**:
   - Lệnh kiểm tra kết nối đến cluster
   - Nếu kết nối được → in thông tin cluster
   - Nếu không → return error

2. **`&> /dev/null`**:
   - `&>`: Redirect cả stdout và stderr
   - `/dev/null`: Null device (discard output)
   - Nghĩa: Bỏ qua output, chỉ quan tâm exit code

3. **`!`**:
   - Negate exit code
   - Nếu `kubectl` success (0) → `!` làm thành false
   - Nếu `kubectl` fail (1) → `!` làm thành true

4. **`if ! kubectl ...`**:
   - Nếu không kết nối được → vào if block
   - In error và exit

**Tại sao cần check?**
- Phải có cluster running trước khi deploy
- Tránh lỗi khi apply manifests

### Dòng 52-58: Deploy Information

```bash
print_info "Deploying Notebook Controller..."
echo "This will install:"
echo "  - Notebook CRD"
echo "  - RBAC (Roles, RoleBindings)"
echo "  - Controller Deployment"
echo "  - Service"
echo ""
```

**Giải thích:**
- In thông tin về những gì sẽ được deploy
- Giúp user hiểu script đang làm gì

### Dòng 61: Change Directory

```bash
cd "$NOTEBOOK_CONTROLLER_PATH"
```

**Giải thích:**
- Chuyển vào thư mục notebook-controller
- **Tại sao cần?**
  - `kustomize build` dùng relative paths
  - Phải ở đúng thư mục để kustomize tìm được base/overlays

### Dòng 64-65: Build và Apply Manifests

```bash
print_info "Building manifests with standalone overlay..."
kustomize build overlays/standalone | kubectl apply -f -
```

**Giải thích từng phần:**

1. **`kustomize build overlays/standalone`**:
   - Build manifests từ standalone overlay
   - `overlays/standalone/`: Thư mục chứa overlay config
   - Output: YAML manifests (stdout)

2. **`|`**: Pipe operator
   - Lấy output từ lệnh trước → làm input cho lệnh sau

3. **`kubectl apply -f -`**:
   - `-f -`: Đọc từ stdin (thay vì file)
   - `-`: Đại diện cho stdin
   - Apply manifests vào cluster

**Standalone Overlay là gì?**
- Overlay customize base manifests
- Standalone = không cần Istio, không cần Kubeflow dependencies
- File: `overlays/standalone/kustomization.yaml`

**Kustomize Flow:**
```
overlays/standalone/kustomization.yaml
    ↓ (references)
../../base/
    ↓ (build)
Combined YAML manifests
    ↓ (apply)
Kubernetes cluster
```

### Dòng 70-73: Wait for CRD

```bash
print_info "Waiting for Notebook CRD to be ready..."
kubectl wait --for condition=established --timeout=60s crd/notebooks.kubeflow.org 2>/dev/null || true
print_success "Notebook CRD ready"
```

**Giải thích từng phần:**

1. **`kubectl wait`**:
   - Đợi resource đạt một condition
   - Blocking command (chờ đến khi condition đạt hoặc timeout)

2. **`--for condition=established`**:
   - Condition cho CRD
   - `established`: CRD đã được API server accept
   - CRD phải established trước khi tạo custom resources

3. **`crd/notebooks.kubeflow.org`**:
   - Resource type và name
   - `crd/`: Custom Resource Definition
   - `notebooks.kubeflow.org`: CRD name

4. **`--timeout=60s`**:
   - Timeout sau 60 giây
   - Nếu không established trong 60s → fail

5. **`2>/dev/null`**:
   - Redirect stderr (error messages) vào /dev/null
   - Ẩn error messages nếu có

6. **`|| true`**:
   - `||`: OR operator
   - Nếu lệnh trước fail → chạy `true` (luôn success)
   - Nghĩa: Nếu wait fail, vẫn tiếp tục script (không exit)

**Tại sao cần wait?**
- CRD phải established trước khi tạo Notebook resources
- Nếu không → `kubectl apply notebook.yaml` sẽ fail

### Dòng 76-79: Wait for Controller Pod

```bash
print_info "Waiting for Notebook Controller to be ready..."
kubectl wait --for=condition=ready pod -l app=notebook-controller --timeout=180s -n notebook-controller-system 2>/dev/null || true
print_success "Notebook Controller ready"
```

**Giải thích từng phần:**

1. **`--for=condition=ready`**:
   - Condition cho Pod
   - `ready`: Pod đã start và containers ready
   - Tất cả containers phải running và readiness probe passed

2. **`pod -l app=notebook-controller`**:
   - `pod`: Resource type
   - `-l`: Label selector
   - `app=notebook-controller`: Label filter
   - Chỉ wait pods có label này

3. **`-n notebook-controller-system`**:
   - Namespace
   - Controller được deploy vào namespace này

4. **`--timeout=180s`**:
   - Timeout 180 giây (3 phút)
   - Pod có thể cần thời gian để pull image và start

**Pod Ready Condition:**
- Containers started
- Readiness probe passed (nếu có)
- Pod có thể nhận traffic

### Dòng 82: Return to Original Directory

```bash
cd - > /dev/null
```

**Giải thích:**
- `cd -`: Quay về directory trước đó
- `> /dev/null`: Ẩn output (không cần in path)
- Giữ working directory sạch sẽ

### Dòng 84-87: Verify Deployment

```bash
print_info "Verifying deployment..."
CONTROLLER_READY=$(kubectl get pods -n notebook-controller-system -l app=notebook-controller --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
CRD_EXISTS=$(kubectl get crd notebooks.kubeflow.org 2>/dev/null | wc -l)
```

**Giải thích từng phần:**

1. **`CONTROLLER_READY=$(...)`**:
   - Command substitution: Lấy output của command
   - Lưu vào biến `CONTROLLER_READY`

2. **`kubectl get pods ...`**:
   - `-n notebook-controller-system`: Namespace
   - `-l app=notebook-controller`: Label selector
   - `--field-selector=status.phase=Running`: Chỉ lấy pods đang Running
   - `--no-headers`: Bỏ header line

3. **`| wc -l`**:
   - `wc -l`: Word count lines
   - Đếm số dòng (số pods)
   - Nếu có 1 pod Running → `CONTROLLER_READY = 1`

4. **`CRD_EXISTS=$(...)`**:
   - Kiểm tra CRD tồn tại
   - `wc -l`: Đếm số dòng
   - Nếu CRD tồn tại → `CRD_EXISTS = 1`

**Verification Logic:**
- Nếu `CONTROLLER_READY > 0` và `CRD_EXISTS > 0` → deployment thành công
- Nếu không → có vấn đề

### Dòng 89-104: Success Message

```bash
if [ "$CONTROLLER_READY" -gt 0 ] && [ "$CRD_EXISTS" -gt 0 ]; then
    print_success "Notebook Controller deployed successfully! 🎉"
    echo ""
    echo "========================================"
    echo "Deployment Summary"
    echo "========================================"
    echo "Namespace: notebook-controller-system"
    echo "CRD: notebooks.kubeflow.org"
    echo ""
    echo "Controller Pods:"
    kubectl get pods -n notebook-controller-system
    echo ""
    echo "Next steps:"
    echo "  1. Create a Notebook: ./scripts/07_create_notebook.sh"
    echo "  2. Check status: kubectl get notebooks"
    echo "  3. Access notebook: ./scripts/08_access_notebook.sh"
    echo ""
```

**Giải thích:**
- `[ "$CONTROLLER_READY" -gt 0 ]`: So sánh số (greater than)
- `&&`: AND operator (cả hai điều kiện phải true)
- Nếu cả hai đều > 0 → in success message và next steps

### Dòng 106-114: Error Handling

```bash
else
    print_error "Deployment verification failed"
    echo "Controller ready: $CONTROLLER_READY"
    echo "CRD exists: $CRD_EXISTS"
    echo ""
    echo "Check logs:"
    echo "  kubectl logs -n notebook-controller-system -l app=notebook-controller"
    exit 1
fi
```

**Giải thích:**
- Nếu verification fail → in error
- In giá trị để debug
- Hướng dẫn check logs
- Exit với error code 1

---

## Script 07: Create Notebook

**File:** `scripts/07_create_notebook.sh`

### Dòng 25-31: Check CRD Exists

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
- Nếu không có → hướng dẫn deploy controller trước

### Dòng 39-41: Get Namespace

```bash
read -p "Enter namespace for notebook (default: default): " NOTEBOOK_NAMESPACE
NOTEBOOK_NAMESPACE=${NOTEBOOK_NAMESPACE:-default}
```

**Giải thích từng phần:**

1. **`read -p "..." NOTEBOOK_NAMESPACE`**:
   - `read`: Đọc input từ user
   - `-p`: Prompt message
   - `NOTEBOOK_NAMESPACE`: Biến lưu input

2. **`${NOTEBOOK_NAMESPACE:-default}`**:
   - **Parameter expansion với default value**
   - Syntax: `${var:-default}`
   - Nếu `$NOTEBOOK_NAMESPACE` rỗng/null → dùng "default"
   - Nếu có giá trị → dùng giá trị đó

**Ví dụ:**
```bash
# User nhấn Enter (rỗng)
NOTEBOOK_NAMESPACE="" → ${NOTEBOOK_NAMESPACE:-default} → "default"

# User nhập "my-ns"
NOTEBOOK_NAMESPACE="my-ns" → ${NOTEBOOK_NAMESPACE:-default} → "my-ns"
```

### Dòng 43-49: Create Namespace

```bash
if ! kubectl get namespace "$NOTEBOOK_NAMESPACE" &> /dev/null; then
    print_info "Creating namespace: $NOTEBOOK_NAMESPACE"
    kubectl create namespace "$NOTEBOOK_NAMESPACE"
    print_success "Namespace created"
    echo ""
fi
```

**Giải thích:**
- Kiểm tra namespace tồn tại
- Nếu không → tạo mới
- Namespace cần thiết để isolate resources

### Dòng 51-58: Choose Notebook Type

```bash
print_header "Choose Notebook Type"
echo "1. Basic Jupyter (CPU only)"
echo "2. Jupyter with TensorFlow (CPU)"
echo "3. Jupyter with TensorFlow (GPU - requires GPU nodes)"
echo "4. Custom YAML file"
echo ""
read -p "Enter choice (1-4): " NOTEBOOK_TYPE
```

**Giải thích:**
- Menu để user chọn notebook type
- Mỗi type có config khác nhau (image, resources)

### Dòng 60-97: Case Statement

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
```

**Giải thích từng phần:**

1. **`case $NOTEBOOK_TYPE in`**:
   - Switch statement trong bash
   - So sánh `$NOTEBOOK_TYPE` với các patterns

2. **`1)`, `2)`, `3)`, `4)`**:
   - Patterns để match
   - `1)`: Nếu `$NOTEBOOK_TYPE = "1"`

3. **`;;`**:
   - End của mỗi case
   - Tương đương `break` trong switch

4. **`*)`**:
   - Default case (match mọi thứ)
   - Nếu không match case nào → vào đây

5. **Option 4 (Custom YAML)**:
   - Đọc path từ user
   - `[ ! -f "$YAML_FILE" ]`: Kiểm tra file tồn tại
   - Apply YAML trực tiếp
   - `exit 0`: Exit với success (không cần tạo YAML nữa)

**Notebook Images:**
- `jupyter-scipy`: Basic với SciPy stack
- `jupyter-tensorflow-full`: TensorFlow đầy đủ
- `jupyter-tensorflow-cuda-full`: TensorFlow + CUDA (GPU)

### Dòng 99-100: Create Temp File

```bash
TEMP_YAML=$(mktemp)
```

**Giải thích:**
- `mktemp`: Tạo temporary file
- Trả về path đến file (ví dụ: `/tmp/tmp.XXXXXX`)
- File tự động có unique name
- Tự động cleanup khi script exit (hoặc manual delete)

**Tại sao dùng temp file?**
- Tạo YAML động dựa trên user input
- Không cần lưu file vĩnh viễn
- Tránh conflict nếu nhiều users chạy cùng lúc

### Dòng 102-128: Generate GPU Notebook YAML

```bash
if [ "$NOTEBOOK_TYPE" = "3" ] && [ -n "$GPU" ]; then
    # GPU notebook
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
EOF
```

**Giải thích từng phần:**

1. **`[ "$NOTEBOOK_TYPE" = "3" ]`**:
   - Kiểm tra nếu là GPU notebook

2. **`[ -n "$GPU" ]`**:
   - `-n`: Test nếu string không rỗng
   - Đảm bảo biến `$GPU` đã được set

3. **`cat > "$TEMP_YAML" <<EOF`**:
   - **Heredoc syntax**
   - `<<EOF`: Bắt đầu heredoc block
   - `EOF`: Kết thúc heredoc (phải ở đầu dòng, không có spaces)
   - `> "$TEMP_YAML"`: Write vào file (overwrite)

4. **YAML Content**:
   - `apiVersion: kubeflow.org/v1`: API version của Notebook CRD
   - `kind: Notebook`: Resource type
   - `$NOTEBOOK_NAME`, `$NOTEBOOK_NAMESPACE`: Variable expansion
   - `spec.template.spec`: Pod template (giống Pod spec)
   - `env: - name: NVIDIA_VISIBLE_DEVICES`: Environment variable cho GPU
   - `nvidia.com/gpu: ${GPU}`: GPU resource request/limit

**GPU Requirements:**
- Cluster phải có GPU nodes
- NVIDIA device plugin phải được cài
- Node phải có label: `accelerator=nvidia-tesla-*`

### Dòng 129-151: Generate CPU Notebook YAML

```bash
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
EOF
fi
```

**Giải thích:**
- Tương tự GPU notebook nhưng không có GPU resources
- Không có `env: NVIDIA_VISIBLE_DEVICES`

### Dòng 153-159: Add Workspace Volume

```bash
cat >> "$TEMP_YAML" <<EOF
  volumes:
  - name: workspace
    persistentVolumeClaim:
      claimName: ${NOTEBOOK_NAME}-workspace
EOF
```

**Giải thích từng phần:**

1. **`cat >>`**:
   - `>>`: Append (không overwrite)
   - Thêm vào cuối file

2. **`volumes:`**:
   - Pod volumes section
   - Định nghĩa volumes để mount vào containers

3. **`persistentVolumeClaim:`**:
   - Volume type: PVC
   - Mount PVC vào pod

4. **`claimName: ${NOTEBOOK_NAME}-workspace`**:
   - Tên PVC
   - Format: `<notebook-name>-workspace`
   - Ví dụ: `basic-notebook-workspace`

**Tại sao cần workspace volume?**
- Persist data giữa các lần restart
- Lưu notebooks, models, data
- Share data giữa containers (nếu có)

### Dòng 161-178: Create PVC

```bash
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
```

**Giải thích từng phần:**

1. **`"${TEMP_YAML}.pvc"`**:
   - Tạo file PVC riêng
   - Tên: `<temp-file>.pvc`
   - Ví dụ: `/tmp/tmp.XXXXXX.pvc`

2. **`PersistentVolumeClaim`**:
   - Kubernetes resource để request storage
   - PVC → PV (Persistent Volume) → Storage backend

3. **`accessModes: ReadWriteOnce`**:
   - Chỉ một pod có thể mount
   - Phù hợp cho single notebook
   - `ReadWriteMany`: Nhiều pods (cần storage hỗ trợ)

4. **`storage: 10Gi`**:
   - Request 10 GiB storage
   - Cluster sẽ provision PV

5. **`kubectl apply -f "${TEMP_YAML}.pvc"`**:
   - Apply PVC vào cluster
   - Kubernetes sẽ tìm PV phù hợp và bind

**PVC Lifecycle:**
```
User tạo PVC
    ↓
Kubernetes tìm PV phù hợp
    ↓
Bind PVC với PV
    ↓
Pod mount PVC
    ↓
Data persist
```

### Dòng 181-184: Apply Notebook

```bash
print_info "Creating Notebook: $NOTEBOOK_NAME"
kubectl apply -f "$TEMP_YAML"
print_success "Notebook created"
```

**Giải thích:**
- Apply Notebook resource vào cluster
- Controller sẽ detect và tạo Pod/Service

**What happens next:**
1. Notebook resource created
2. Controller watches và detect
3. Controller tạo Pod từ `spec.template`
4. Controller tạo Service để expose
5. Controller update `status.ready`

### Dòng 186-188: Cleanup Temp Files

```bash
rm -f "$TEMP_YAML" "${TEMP_YAML}.pvc"
```

**Giải thích:**
- `rm -f`: Remove file (force, không hỏi)
- Xóa temp files sau khi dùng
- `-f`: Không fail nếu file không tồn tại

### Dòng 190-203: Wait for Ready

```bash
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
```

**Giải thích từng phần:**

1. **`for i in {1..30}`**:
   - Loop 30 lần
   - `{1..30}`: Brace expansion (1, 2, 3, ..., 30)
   - Tối đa 30 lần check (150 giây = 2.5 phút)

2. **`STATUS=$(...)`**:
   - Command substitution
   - Lấy `status.ready` từ Notebook

3. **`kubectl get notebook ... -o jsonpath='{.status.ready}'`**:
   - `-o jsonpath='{.status.ready}'`: JSONPath expression
   - `.status.ready`: Path trong JSON
   - Trả về: `"true"` hoặc `"false"`

4. **`2>/dev/null || echo "false"`**:
   - Nếu lệnh fail → dùng "false" (default)
   - Tránh script fail nếu Notebook chưa có status

5. **`if [ "$STATUS" = "true" ]`**:
   - So sánh string
   - Nếu ready → in success và break

6. **`echo -n "."`**:
   - `-n`: Không xuống dòng
   - In dấu chấm (progress indicator)

7. **`sleep 5`**:
   - Đợi 5 giây trước khi check lại

**Notebook Status:**
- `status.ready = true`: Pod đã start và ready
- `status.ready = false`: Đang khởi tạo hoặc có lỗi

---

## Script 08: Access Notebook

**File:** `scripts/08_access_notebook.sh`

### Dòng 31-40: List Available Notebooks

```bash
print_header "Available Notebooks"
NOTEBOOKS=$(kubectl get notebooks -A --no-headers 2>/dev/null | awk '{print $2 " -n " $1}')

if [ -z "$NOTEBOOKS" ]; then
    print_error "No notebooks found!"
    echo "Please create a notebook first:"
    echo "  ./scripts/07_create_notebook.sh"
    exit 1
fi
```

**Giải thích từng phần:**

1. **`kubectl get notebooks -A`**:
   - `-A`: All namespaces
   - Lấy notebooks từ tất cả namespaces

2. **`--no-headers`**:
   - Bỏ header line
   - Chỉ lấy data rows

3. **`| awk '{print $2 " -n " $1}'`**:
   - `awk`: Text processing tool
   - `$1`: Field đầu tiên (namespace)
   - `$2`: Field thứ hai (name)
   - Output format: `notebook-name -n namespace`

**Output example:**
```
default    my-notebook    True    5m
my-ns      another        False   2m
```
→
```
my-notebook -n default
another -n my-ns
```

### Dòng 47-55: Get Notebook Name and Namespace

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
- Nếu không có tham số → prompt user (interactive)
- Nếu có tham số → dùng tham số (script có thể gọi với args)

**Usage:**
```bash
# Interactive
./scripts/08_access_notebook.sh

# With arguments
./scripts/08_access_notebook.sh my-notebook default
```

### Dòng 66-79: Check Notebook Ready

```bash
READY=$(kubectl get notebook "$NOTEBOOK_NAME" -n "$NOTEBOOK_NAMESPACE" -o jsonpath='{.status.ready}' 2>/dev/null || echo "false")
if [ "$READY" != "true" ]; then
    print_error "Notebook is not ready yet!"
    echo ""
    echo "Current status:"
    kubectl get notebook "$NOTEBOOK_NAME" -n "$NOTEBOOK_NAMESPACE"
    echo ""
    echo "Check pod status:"
    kubectl get pods -n "$NOTEBOOK_NAMESPACE" -l notebook-name="$NOTEBOOK_NAME"
    echo ""
    echo "Wait for notebook to be ready, then try again."
    exit 1
fi
```

**Giải thích:**
- Kiểm tra `status.ready`
- Nếu không ready → in lỗi và exit
- Phải đợi notebook ready trước khi access

### Dòng 81-87: Get Pod Name

```bash
POD_NAME=$(kubectl get pods -n "$NOTEBOOK_NAMESPACE" -l notebook-name="$NOTEBOOK_NAME" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$POD_NAME" ]; then
    print_error "Pod not found for notebook '$NOTEBOOK_NAME'"
    exit 1
fi
```

**Giải thích từng phần:**

1. **`-l notebook-name="$NOTEBOOK_NAME"`**:
   - Label selector
   - Controller tự động thêm label `notebook-name` vào pod

2. **`{.items[0].metadata.name}`**:
   - JSONPath expression
   - `.items[0]`: Pod đầu tiên trong list
   - `.metadata.name`: Tên pod

3. **`[ -z "$POD_NAME" ]`**:
   - Kiểm tra pod name rỗng
   - Nếu không tìm thấy pod → exit

**Label Selector:**
- Controller tạo pod với label: `notebook-name=<notebook-name>`
- Dùng để query pods của một notebook

### Dòng 89-90: Get Port

```bash
PORT=${3:-8888}
```

**Giải thích:**
- `$3`: Tham số thứ ba (port)
- `${3:-8888}`: Default 8888 nếu không có
- Jupyter default port là 8888

### Dòng 100-122: Get Access Token

```bash
print_info "Getting access token..."
TOKEN=$(kubectl exec -n "$NOTEBOOK_NAMESPACE" "$POD_NAME" -- jupyter notebook list 2>/dev/null | grep -oP 'token=\K[^\s]+' | head -1 || echo "")

if [ -z "$TOKEN" ]; then
    print_info "Token not found, you may need to check logs:"
    echo "  kubectl logs -n $NOTEBOOK_NAMESPACE $POD_NAME"
    echo ""
    print_info "Starting port-forward..."
    echo "You may need to access the notebook and get the token from the logs."
else
    print_success "Token found!"
    echo ""
    echo "========================================"
    echo "Access Information"
    echo "========================================"
    echo "URL: http://localhost:$PORT"
    echo "Token: $TOKEN"
    echo ""
    echo "Full URL: http://localhost:$PORT/?token=$TOKEN"
    echo ""
fi
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
   - Extract token từ URL

4. **`head -1`**:
   - Lấy dòng đầu tiên (nếu có nhiều servers)

5. **`|| echo ""`**:
   - Nếu fail → dùng empty string

**Token Purpose:**
- Jupyter yêu cầu token để authenticate
- Token được generate tự động khi start
- Có thể disable (không khuyến nghị)

### Dòng 132-133: Port Forward

```bash
kubectl port-forward -n "$NOTEBOOK_NAMESPACE" "$POD_NAME" "$PORT:8888"
```

**Giải thích từng phần:**

1. **`kubectl port-forward`**:
   - Forward port từ pod đến local
   - Tạo tunnel qua API server

2. **`$PORT:8888`**:
   - `$PORT`: Local port (ví dụ: 8888)
   - `8888`: Pod port (Jupyter default)
   - Format: `local:pod`

3. **Blocking command**:
   - Chạy đến khi Ctrl+C
   - Không thể chạy tiếp script

**How Port Forward Works:**
```
localhost:$PORT
    ↓ (kubectl tunnel)
API Server
    ↓ (forward)
Pod port 8888
```

**Access:**
- URL: `http://localhost:$PORT`
- Với token: `http://localhost:$PORT/?token=$TOKEN`

---

## Script 09: Check Status

**File:** `scripts/09_check_notebook_status.sh`

### Dòng 40-49: Get All Notebooks

```bash
print_header "All Notebooks"
NOTEBOOKS=$(kubectl get notebooks -A --no-headers 2>/dev/null)

if [ -z "$NOTEBOOKS" ]; then
    print_info "No notebooks found"
    echo ""
    echo "Create a notebook:"
    echo "  ./scripts/07_create_notebook.sh"
    exit 0
fi

kubectl get notebooks -A
echo ""
```

**Giải thích:**
- Lấy tất cả notebooks từ tất cả namespaces
- Nếu không có → in message và exit
- Nếu có → hiển thị table

### Dòng 54-99: Parse và Display Details

```bash
while IFS= read -r line; do
    if [ -z "$line" ]; then
        continue
    fi
    
    NAMESPACE=$(echo "$line" | awk '{print $1}')
    NAME=$(echo "$line" | awk '{print $2}')
    READY=$(echo "$line" | awk '{print $3}')
    AGE=$(echo "$line" | awk '{print $4}')
    
    echo "----------------------------------------"
    echo "Notebook: $NAME (namespace: $NAMESPACE)"
    echo "----------------------------------------"
    echo "Ready: $READY"
    echo "Age: $AGE"
    echo ""
    
    # Get pod status
    POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l notebook-name="$NAME" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -n "$POD_NAME" ]; then
        echo "Pod: $POD_NAME"
        POD_STATUS=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
        echo "Pod Status: $POD_STATUS"
        
        # Get resource usage if metrics available
        if kubectl top pod "$POD_NAME" -n "$NAMESPACE" &> /dev/null; then
            echo "Resource Usage:"
            kubectl top pod "$POD_NAME" -n "$NAMESPACE"
        fi
    else
        print_error "No pod found for this notebook"
    fi
    
    echo ""
    
    # Get events
    echo "Recent Events:"
    kubectl get events -n "$NAMESPACE" --field-selector involvedObject.name="$NAME" --sort-by='.lastTimestamp' | tail -3
    echo ""
    
done <<< "$NOTEBOOKS"
```

**Giải thích từng phần:**

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

4. **`kubectl top pod`**:
   - Hiển thị resource usage
   - Cần metrics-server hoặc cAdvisor
   - Nếu không có → skip (không fail)

5. **`kubectl get events`**:
   - Lấy events liên quan
   - `--field-selector`: Filter theo object name
   - `--sort-by='.lastTimestamp'`: Sort theo thời gian
   - `tail -3`: Lấy 3 events gần nhất

**Pod Phases:**
- `Pending`: Đang chờ schedule
- `Running`: Đang chạy
- `Succeeded`: Completed successfully
- `Failed`: Có lỗi
- `Unknown`: Không xác định được

### Dòng 101-116: Summary

```bash
print_header "Summary"
TOTAL=$(echo "$NOTEBOOKS" | wc -l)
READY_COUNT=$(echo "$NOTEBOOKS" | grep -c "True" || echo "0")

echo "Total Notebooks: $TOTAL"
echo "Ready: $READY_COUNT"
echo "Not Ready: $((TOTAL - READY_COUNT))"
echo ""

if [ "$READY_COUNT" -eq "$TOTAL" ] && [ "$TOTAL" -gt 0 ]; then
    print_success "All notebooks are ready! 🎉"
else
    print_info "Some notebooks are not ready yet"
    echo "Wait a few minutes and run this script again"
fi
```

**Giải thích:**
- `wc -l`: Đếm số dòng (tổng notebooks)
- `grep -c "True"`: Đếm số dòng chứa "True" (ready notebooks)
- `$((TOTAL - READY_COUNT))`: Arithmetic expansion
- In summary statistics

---

## Notebook YAML Examples

### Basic Notebook YAML

**File:** `examples/notebooks/basic-notebook.yaml`

```yaml
apiVersion: kubeflow.org/v1
kind: Notebook
metadata:
  name: basic-notebook
  namespace: default
spec:
  template:
    spec:
      containers:
      - name: basic-notebook
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
      claimName: basic-notebook-workspace
```

**Giải thích từng field:**

1. **`apiVersion: kubeflow.org/v1`**:
   - API version của Notebook CRD
   - `kubeflow.org`: API group
   - `v1`: Version

2. **`kind: Notebook`**:
   - Resource type
   - Được định nghĩa bởi CRD

3. **`metadata.name`**:
   - Tên Notebook resource
   - Phải unique trong namespace

4. **`spec.template.spec`**:
   - Pod template
   - Controller sẽ dùng để tạo Pod
   - Giống Pod spec

5. **`resources.requests`**:
   - Minimum resources cần
   - Kubernetes scheduler dùng để schedule

6. **`resources.limits`**:
   - Maximum resources được dùng
   - Kubelet enforce (kill nếu vượt)

7. **`volumes`**:
   - Pod volumes
   - `persistentVolumeClaim`: Mount PVC

### GPU Notebook YAML

**File:** `examples/notebooks/gpu-notebook.yaml`

```yaml
apiVersion: kubeflow.org/v1
kind: Notebook
metadata:
  name: gpu-notebook
  namespace: default
spec:
  template:
    spec:
      containers:
      - name: gpu-notebook
        image: kubeflownotebookswg/jupyter-tensorflow-cuda-full:latest
        env:
        - name: NVIDIA_VISIBLE_DEVICES
          value: "all"
        resources:
          requests:
            cpu: "2.0"
            memory: 4Gi
            nvidia.com/gpu: "1"
          limits:
            cpu: "4.0"
            memory: 8Gi
            nvidia.com/gpu: "1"
  volumes:
  - name: workspace
    persistentVolumeClaim:
      claimName: gpu-notebook-workspace
```

**Khác biệt với CPU notebook:**

1. **`env: - name: NVIDIA_VISIBLE_DEVICES`**:
   - Environment variable cho NVIDIA GPU
   - `"all"`: Expose tất cả GPUs

2. **`nvidia.com/gpu: "1"`**:
   - GPU resource request/limit
   - `nvidia.com/gpu`: Extended resource type
   - Cần NVIDIA device plugin

**GPU Requirements:**
- Cluster phải có GPU nodes
- NVIDIA device plugin phải được cài
- Node phải có label: `accelerator=nvidia-tesla-*`

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
└── standalone/
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

