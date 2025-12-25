# 📚 Tài Liệu Chi Tiết Các Scripts Kubeflow

Tài liệu này giải thích chi tiết từng dòng code, từng lệnh trong các scripts deploy Kubeflow.

---

## 📋 Mục Lục

1. [Script 01: Install Prerequisites](#script-01-install-prerequisites)
2. [Script 02: Deploy Kubeflow](#script-02-deploy-kubeflow)
3. [Script 03: Check Status](#script-03-check-status)
4. [Script 04: Access Dashboard](#script-04-access-dashboard)
5. [Script 05: Cleanup](#script-05-cleanup)

---

## Script 01: Install Prerequisites

**File:** `scripts/01_install_prerequisites.sh`

**Mục đích:** Kiểm tra và cài đặt các công cụ cần thiết trước khi deploy Kubeflow.

### Phân Tích Chi Tiết

#### 1. Shebang và Set Options

```bash
#!/bin/bash
set -e
```

- `#!/bin/bash`: Chỉ định shell interpreter là bash
- `set -e`: **Quan trọng!** Script sẽ dừng ngay khi gặp lệnh trả về exit code khác 0 (lỗi). Điều này đảm bảo script không tiếp tục chạy khi có lỗi.

#### 2. Colors và Functions

```bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
```

**Giải thích:**
- `\033[0;31m`: ANSI escape code để đổi màu text sang đỏ
- `\033[0;32m`: Màu xanh lá
- `\033[1;33m`: Màu vàng đậm
- `\033[0m`: Reset về màu mặc định
- `NC='\033[0m'`: Biến để reset màu sau khi in

```bash
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}
```

**Giải thích:**
- `echo -e`: Cho phép interpret escape sequences (như `\033`)
- `${GREEN}`: In màu xanh
- `✓`: Ký tự checkmark
- `$1`: Tham số đầu tiên truyền vào function
- `${NC}`: Reset màu về mặc định

#### 3. Kiểm Tra kubectl

```bash
if command -v kubectl &> /dev/null; then
```

**Giải thích:**
- `command -v kubectl`: Tìm xem kubectl có trong PATH không
- `&> /dev/null`: Redirect cả stdout và stderr vào /dev/null (ẩn output)
- Nếu kubectl tồn tại → trả về 0 (true), không tồn tại → trả về 1 (false)

```bash
KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null || kubectl version --client 2>/dev/null | grep "Client Version")
```

**Giải thích:**
- `$(...)`: Command substitution - chạy lệnh và lấy output
- `kubectl version --client --short`: Lấy version ngắn gọn
- `2>/dev/null`: Bỏ qua lỗi nếu có
- `||`: Nếu lệnh trước fail, chạy lệnh sau
- `grep "Client Version"`: Tìm dòng chứa "Client Version"

**Nếu kubectl chưa có:**

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
```

**Giải thích:**
- `curl -L`: Follow redirects
- `curl -O`: Save file với tên gốc
- `curl -s`: Silent mode (không hiện progress)
- `$(curl -L -s ...)`: Lấy version stable mới nhất
- Kết quả: Download kubectl binary cho Linux AMD64

```bash
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

**Giải thích:**
- `chmod +x`: Thêm quyền execute
- `sudo mv`: Di chuyển file vào `/usr/local/bin/` (cần sudo vì đây là system directory)

#### 4. Kiểm Tra Kết Nối Cluster

```bash
if kubectl cluster-info &> /dev/null; then
```

**Giải thích:**
- `kubectl cluster-info`: Kiểm tra kết nối đến cluster
- `&> /dev/null`: Ẩn output, chỉ quan tâm exit code
- Nếu thành công → cluster đang chạy và kubeconfig đúng

```bash
kubectl cluster-info
```

**Giải thích:**
- In thông tin cluster (control plane URL, DNS service)

**Nếu không kết nối được:**

```bash
exit 1
```

**Giải thích:**
- `exit 1`: Thoát script với exit code 1 (lỗi)
- Script dừng lại, không tiếp tục

#### 5. Kiểm Tra kustomize

```bash
if command -v kustomize &> /dev/null; then
```

**Tương tự như kubectl**, kiểm tra xem kustomize đã cài chưa.

**Nếu chưa có:**

```bash
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
```

**Giải thích:**
- `curl -s`: Download script install kustomize
- `| bash`: Pipe output vào bash để chạy script
- Script này sẽ download và cài kustomize

#### 6. Kiểm Tra jq

```bash
sudo apt-get update -qq
sudo apt-get install -y jq
```

**Giải thích:**
- `apt-get update -qq`: Update package list (quiet mode)
- `apt-get install -y jq`: Cài jq, `-y` = tự động yes

#### 7. Kiểm Tra Cluster Resources

```bash
kubectl get nodes -o wide
```

**Giải thích:**
- `get nodes`: Lấy danh sách nodes
- `-o wide`: Output format rộng (hiện thêm IP, OS, kernel version)

```bash
kubectl get storageclass
```

**Giải thích:**
- `get storageclass`: Lấy danh sách storage classes
- Storage class định nghĩa cách tạo persistent volumes

#### 8. Kiểm Tra Metrics Server

```bash
if kubectl get deployment metrics-server -n kube-system &> /dev/null; then
```

**Giải thích:**
- `get deployment metrics-server`: Kiểm tra deployment metrics-server
- `-n kube-system`: Trong namespace kube-system
- Metrics server cung cấp resource usage (CPU, memory)

```bash
kubectl top nodes 2>/dev/null || echo "Metrics not available yet, please wait..."
```

**Giải thích:**
- `kubectl top nodes`: Hiển thị CPU/memory usage của nodes
- `2>/dev/null`: Ẩn lỗi
- `|| echo ...`: Nếu lệnh fail, in thông báo

#### 9. Kiểm Tra Minimum Requirements

```bash
TOTAL_CPU=$(kubectl get nodes -o json | jq '[.items[].status.capacity.cpu | tonumber] | add')
```

**Giải thích từng phần:**

1. `kubectl get nodes -o json`: Lấy thông tin nodes dạng JSON
2. `jq`: Tool parse JSON
3. `.items[]`: Lặp qua từng node trong mảng items
4. `.status.capacity.cpu`: Lấy giá trị CPU capacity
5. `tonumber`: Convert string sang number
6. `add`: Tính tổng tất cả CPU

**Ví dụ output JSON:**
```json
{
  "items": [
    {
      "status": {
        "capacity": {
          "cpu": "12"
        }
      }
    }
  ]
}
```

```bash
TOTAL_MEM_KB=$(kubectl get nodes -o json | jq '[.items[].status.capacity.memory | gsub("Ki"; "") | tonumber] | add')
TOTAL_MEM_GB=$(echo "scale=2; $TOTAL_MEM_KB / 1024 / 1024" | bc)
```

**Giải thích:**
- `gsub("Ki"; "")`: Xóa "Ki" khỏi string (ví dụ: "16Gi" → "16")
- `/ 1024 / 1024`: Convert từ KB → MB → GB
- `bc`: Calculator tool để tính toán
- `scale=2`: Làm tròn 2 chữ số thập phân

```bash
if (( $(echo "$TOTAL_CPU >= 4" | bc -l) )); then
```

**Giải thích:**
- `echo "$TOTAL_CPU >= 4" | bc -l`: So sánh CPU với 4
- `$((...))`: Arithmetic expansion trong bash
- `bc -l`: Math library mode (hỗ trợ so sánh)

---

## Script 02: Deploy Kubeflow

**File:** `scripts/02_deploy_kubeflow.sh`

**Mục đích:** Deploy Kubeflow lên Kubernetes cluster.

### Phân Tích Chi Tiết

#### 1. Configuration

```bash
MANIFESTS_DIR="./manifests"
KUBEFLOW_VERSION="v1.8.0"
```

**Giải thích:**
- `MANIFESTS_DIR`: Thư mục chứa Kubeflow manifests
- `KUBEFLOW_VERSION`: Version Kubeflow muốn deploy

#### 2. Clone Manifests

```bash
if [ -d "$MANIFESTS_DIR" ]; then
```

**Giải thích:**
- `[ -d "$MANIFESTS_DIR" ]`: Kiểm tra xem thư mục có tồn tại không
- `-d`: Test nếu là directory

```bash
read -p "Do you want to re-clone? (y/n) " -n 1 -r
```

**Giải thích:**
- `read -p "..."`: Prompt user và đọc input
- `-n 1`: Chỉ đọc 1 ký tự
- `-r`: Raw mode (không interpret backslashes)
- Input được lưu vào biến `$REPLY`

```bash
if [[ $REPLY =~ ^[Yy]$ ]]; then
```

**Giải thích:**
- `[[ ... ]]`: Bash conditional expression (mạnh hơn `[ ]`)
- `=~`: Regex matching operator
- `^[Yy]$`: Match "Y" hoặc "y" (bắt đầu và kết thúc)

```bash
git clone https://github.com/kubeflow/manifests.git "$MANIFESTS_DIR"
```

**Giải thích:**
- `git clone`: Clone repository từ GitHub
- Repository chứa tất cả Kubernetes manifests cho Kubeflow

```bash
cd "$MANIFESTS_DIR"
git checkout "$KUBEFLOW_VERSION"
cd ..
```

**Giải thích:**
- `cd`: Chuyển vào thư mục manifests
- `git checkout`: Chuyển sang tag/version cụ thể
- `cd ..`: Quay lại thư mục gốc

#### 3. Chọn Installation Method

```bash
while true; do
    read -p "Enter choice (1 or 2): " INSTALL_METHOD
    INSTALL_METHOD=$(echo "$INSTALL_METHOD" | tr -d '[:space:]')
    if [ "$INSTALL_METHOD" = "1" ] || [ "$INSTALL_METHOD" = "2" ]; then
        break
    else
        print_error "Invalid choice. Please enter 1 or 2."
    fi
done
```

**Giải thích:**
- `while true`: Vòng lặp vô hạn
- `read -p`: Đọc input từ user
- `tr -d '[:space:]'`: Xóa tất cả whitespace (spaces, tabs)
- `break`: Thoát khỏi vòng lặp khi input hợp lệ
- Nếu input không hợp lệ, in lỗi và lặp lại

#### 4. Quick Install (Option 1)

```bash
while ! kustomize build example | kubectl apply -f -; do
    print_info "Retrying to apply resources..."
    sleep 10
done
```

**Giải thích từng phần:**

1. `kustomize build example`:
   - `kustomize`: Tool để customize Kubernetes manifests
   - `build example`: Build manifests từ thư mục `example/`
   - Output: YAML manifests đã được process

2. `| kubectl apply -f -`:
   - `|`: Pipe output sang lệnh tiếp theo
   - `kubectl apply`: Apply manifests lên cluster
   - `-f -`: Đọc từ stdin (dấu `-`)

3. `while ! ... do`:
   - `!`: Negate exit code
   - Nếu `kubectl apply` fail (exit code != 0), `!` làm nó thành true
   - Vòng lặp tiếp tục

4. `sleep 10`: Đợi 10 giây trước khi retry

**Tại sao cần retry?**
- Một số resources phụ thuộc vào nhau
- CRDs cần được tạo trước khi dùng
- Retry đảm bảo tất cả dependencies đã sẵn sàng

#### 5. Step-by-Step Install (Option 2)

Script deploy từng component một, theo thứ tự phụ thuộc.

##### Step 1: Cert Manager

```bash
kustomize build common/cert-manager/cert-manager/base | kubectl apply -f -
```

**Giải thích:**
- `common/cert-manager/cert-manager/base`: Path đến cert-manager manifests
- Cert Manager: Quản lý TLS certificates tự động

```bash
kubectl wait --for=condition=ready pod -l 'app in (cert-manager,webhook)' --timeout=180s -n cert-manager 2>/dev/null || true
```

**Giải thích từng phần:**

1. `kubectl wait`: Đợi resource đạt condition
2. `--for=condition=ready`: Đợi pod ready
3. `-l 'app in (cert-manager,webhook)'`: Label selector (pods có label app=cert-manager hoặc app=webhook)
4. `--timeout=180s`: Timeout sau 180 giây
5. `-n cert-manager`: Trong namespace cert-manager
6. `2>/dev/null`: Ẩn lỗi
7. `|| true`: Nếu lệnh fail, vẫn tiếp tục (không dừng script)

**Tại sao cần wait?**
- Cert Manager cần chạy trước khi các component khác dùng certificates
- Đảm bảo cert-manager pods đã ready

##### Step 2: Istio CRDs

```bash
kustomize build common/istio-1-17/istio-crds/base | kubectl apply -f -
```

**Giải thích:**
- **CRD** = Custom Resource Definition
- Istio CRDs định nghĩa các custom resources (VirtualService, Gateway, etc.)
- CRDs phải được tạo trước khi dùng custom resources

##### Step 3-4: Istio Namespace và Install

```bash
kustomize build common/istio-1-17/istio-namespace/base | kubectl apply -f -
kustomize build common/istio-1-17/istio-install/base | kubectl apply -f -
sleep 30
```

**Giải thích:**
- **Istio**: Service mesh, quản lý traffic giữa services
- `sleep 30`: Đợi 30 giây để Istio khởi động
- Istio cần thời gian để initialize control plane

##### Step 5: Dex (Authentication)

```bash
kustomize build common/dex/overlays/istio | kubectl apply -f -
```

**Giải thích:**
- **Dex**: Identity provider, xử lý authentication
- `overlays/istio`: Overlay configuration cho Istio integration

##### Step 6: OIDC AuthService

```bash
kustomize build common/oidc-client/oidc-authservice/base | kubectl apply -f -
```

**Giải thích:**
- **OIDC**: OpenID Connect protocol
- AuthService xử lý OIDC authentication flow

##### Step 7-8: Knative Serving và Eventing

```bash
kustomize build common/knative/knative-serving/overlays/gateways | kubectl apply -f -
kustomize build common/knative/knative-eventing/base | kubectl apply -f -
```

**Giải thích:**
- **Knative Serving**: Serverless workloads, auto-scaling
- **Knative Eventing**: Event-driven architecture
- `overlays/gateways`: Configuration với Istio gateways

##### Step 9: Kubeflow Namespace

```bash
kustomize build common/kubeflow-namespace/base | kubectl apply -f -
```

**Giải thích:**
- Tạo namespace `kubeflow` chính
- Namespace chứa các Kubeflow core components

##### Step 10: Kubeflow Roles

```bash
kustomize build common/kubeflow-roles/base | kubectl apply -f -
```

**Giải thích:**
- Định nghĩa RBAC (Role-Based Access Control)
- Roles và RoleBindings cho Kubeflow components

##### Step 11: Kubeflow Pipelines

```bash
kustomize build apps/pipeline/upstream/env/cert-manager/platform-agnostic-multi-user | kubectl apply -f -
```

**Giải thích:**
- **Kubeflow Pipelines**: ML workflow orchestration
- `env/cert-manager`: Sử dụng cert-manager cho TLS
- `platform-agnostic-multi-user`: Multi-user support, không phụ thuộc cloud provider

##### Step 12: KServe

```bash
kustomize build contrib/kserve/kserve | kubectl apply -f -
```

**Giải thích:**
- **KServe**: Model serving framework
- Deploy và serve ML models

##### Step 13: Katib

```bash
kustomize build apps/katib/upstream/installs/katib-with-kubeflow | kubectl apply -f -
```

**Giải thích:**
- **Katib**: Hyperparameter tuning
- Tự động tìm best hyperparameters

##### Step 14: Central Dashboard

```bash
kustomize build apps/centraldashboard/upstream/overlays/kserve | kubectl apply -f -
```

**Giải thích:**
- **Central Dashboard**: Web UI chính của Kubeflow
- `overlays/kserve`: Integration với KServe

##### Step 15: Admission Webhook

```bash
kustomize build apps/admission-webhook/upstream/overlays/cert-manager | kubectl apply -f -
```

**Giải thích:**
- **Admission Webhook**: Validate và mutate resources trước khi tạo
- Đảm bảo resources tuân thủ policies

##### Step 16: Notebook Controller ⭐

```bash
kustomize build apps/jupyter/notebook-controller/upstream/overlays/kubeflow | kubectl apply -f -
```

**Giải thích:**
- **Notebook Controller**: Quản lý Jupyter Notebooks
- Component quan trọng nhất cho Task 1
- Tạo CRD `Notebook` và controller để quản lý

##### Step 17: Jupyter Web App

```bash
kustomize build apps/jupyter/jupyter-web-app/upstream/overlays/istio | kubectl apply -f -
```

**Giải thích:**
- **Jupyter Web App**: Web UI để tạo và quản lý notebooks
- Giao diện người dùng cho Notebook Controller

##### Step 18: Additional Components

```bash
kustomize build apps/profiles/upstream/overlays/kubeflow | kubectl apply -f -
kustomize build apps/volumes-web-app/upstream/overlays/istio | kubectl apply -f -
kustomize build apps/tensorboard/tensorboards-web-app/upstream/overlays/istio | kubectl apply -f -
kustomize build apps/tensorboard/tensorboard-controller/upstream/overlays/kubeflow | kubectl apply -f -
kustomize build apps/training-operator/upstream/overlays/kubeflow | kubectl apply -f -
kustomize build common/user-namespace/base | kubectl apply -f -
```

**Giải thích:**
- **Profiles**: User profiles và namespaces
- **Volumes Web App**: Quản lý volumes
- **TensorBoard**: Visualization cho ML experiments
- **Training Operator**: Distributed training (PyTorch, TensorFlow)
- **User Namespace**: Tạo user namespaces tự động

---

## Script 03: Check Status

**File:** `scripts/03_check_status.sh`

**Mục đích:** Kiểm tra trạng thái deployment Kubeflow.

### Phân Tích Chi Tiết

#### 1. Function check_namespace

```bash
check_namespace() {
    local ns=$1
    local name=$2
    ...
}
```

**Giải thích:**
- `local ns=$1`: Biến local, tham số đầu tiên (namespace)
- `local name=$2`: Tham số thứ hai (tên hiển thị)
- `local`: Chỉ có scope trong function

```bash
if ! kubectl get namespace "$ns" &> /dev/null; then
    print_error "Namespace $ns does not exist"
    echo ""
    return
fi
```

**Giải thích:**
- `!`: Negate (nếu namespace không tồn tại)
- `return`: Thoát function sớm
- Nếu namespace không tồn tại, in lỗi và return

```bash
local total=$(kubectl get pods -n "$ns" 2>/dev/null | grep -v NAME | wc -l)
```

**Giải thích:**
- `kubectl get pods -n "$ns"`: Lấy pods trong namespace
- `grep -v NAME`: Loại bỏ dòng header "NAME"
- `wc -l`: Đếm số dòng (số pods)

```bash
local running=$(kubectl get pods -n "$ns" 2>/dev/null | grep Running | wc -l)
```

**Giải thích:**
- `grep Running`: Chỉ lấy pods có status "Running"
- Đếm số pods đang chạy

```bash
local error=$(kubectl get pods -n "$ns" 2>/dev/null | grep -E 'Error|CrashLoopBackOff|ImagePullBackOff' | wc -l)
```

**Giải thích:**
- `grep -E`: Extended regex
- `'Error|CrashLoopBackOff|ImagePullBackOff'`: Match một trong các status lỗi
- Đếm pods có lỗi

**Các Pod Status:**
- `Running`: Pod đang chạy bình thường
- `Pending`: Đang chờ được schedule
- `ContainerCreating`: Đang tạo container
- `PodInitializing`: Đang khởi tạo
- `Error`: Có lỗi
- `CrashLoopBackOff`: Container crash liên tục
- `ImagePullBackOff`: Không pull được image

#### 2. Check CRDs

```bash
kubectl get crd | grep notebook || print_error "No notebook CRDs found"
```

**Giải thích:**
- `kubectl get crd`: Lấy danh sách CRDs
- `grep notebook`: Tìm CRDs liên quan đến notebook
- `||`: Nếu không tìm thấy, in lỗi

#### 3. Overall Summary

```bash
TOTAL_PODS=$(kubectl get pods -A 2>/dev/null | grep -E 'kubeflow|istio-system|knative|cert-manager|auth' | wc -l)
```

**Giải thích:**
- `kubectl get pods -A`: Lấy pods từ tất cả namespaces (`-A` = all)
- `grep -E 'kubeflow|istio-system|...'`: Lọc pods trong các namespaces liên quan
- Đếm tổng số pods

```bash
PERCENTAGE=$((RUNNING_PODS * 100 / TOTAL_PODS))
```

**Giải thích:**
- `$((...))`: Arithmetic expansion
- Tính phần trăm pods đang chạy

#### 4. Check Critical Components

```bash
CRITICAL_MISSING=0
if ! kubectl get namespace kubeflow &> /dev/null; then
    CRITICAL_MISSING=$((CRITICAL_MISSING + 1))
fi
if ! kubectl get crd notebooks.kubeflow.org &> /dev/null; then
    CRITICAL_MISSING=$((CRITICAL_MISSING + 1))
fi
```

**Giải thích:**
- Đếm số critical components còn thiếu
- Nếu thiếu → deployment chưa hoàn thành

#### 5. Status Logic

```bash
if [ "$PERCENTAGE" -eq 100 ] && [ "$CRITICAL_MISSING" -eq 0 ] && [ "$PENDING_PODS" -eq 0 ] && [ "$ERROR_PODS" -eq 0 ]; then
    print_success "Kubeflow is fully deployed! 🎉"
```

**Giải thích:**
- Chỉ báo "fully deployed" khi:
  - 100% pods running
  - Không thiếu critical components
  - Không có pods pending
  - Không có pods lỗi

---

## Script 04: Access Dashboard

**File:** `scripts/04_access_dashboard.sh`

**Mục đích:** Thiết lập truy cập vào Kubeflow dashboard.

### Phân Tích Chi Tiết

#### 1. Check Service

```bash
if ! kubectl get svc istio-ingressgateway -n istio-system &> /dev/null; then
    echo "Error: istio-ingressgateway service not found"
    exit 1
fi
```

**Giải thích:**
- `kubectl get svc`: Lấy service
- `istio-ingressgateway`: Service gateway của Istio
- Nếu không có → Kubeflow chưa deploy xong

#### 2. Port Forward (Option 1)

```bash
kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80 --address 0.0.0.0
```

**Giải thích từng phần:**

1. `kubectl port-forward`: Forward port từ pod/service
2. `-n istio-system`: Namespace
3. `svc/istio-ingressgateway`: Service name
4. `8080:80`: Forward port 8080 (local) → 80 (service)
5. `--address 0.0.0.0`: Listen trên tất cả interfaces (cho phép truy cập từ máy khác)

**Cách hoạt động:**
- Tạo tunnel từ local port 8080 đến service port 80
- Truy cập `http://localhost:8080` → được forward đến service

**Lưu ý:** Lệnh này chạy blocking (không return), cần Ctrl+C để dừng.

#### 3. NodePort (Option 2)

```bash
kubectl patch svc istio-ingressgateway -n istio-system -p '{"spec":{"type":"NodePort"}}'
```

**Giải thích:**
- `kubectl patch`: Update service với JSON patch
- `'{"spec":{"type":"NodePort"}}'`: Đổi service type sang NodePort
- NodePort: Expose service qua node IP và port cố định

```bash
NODE_PORT=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
```

**Giải thích:**
- `-o jsonpath='...'`: Extract giá trị từ JSON
- `.spec.ports[?(@.name=="http2")]`: Tìm port có name="http2"
- `.nodePort`: Lấy nodePort được assign

**JSONPath syntax:**
- `.spec`: Access spec field
- `.ports[]`: Array of ports
- `[?(@.name=="http2")]`: Filter (port có name="http2")
- `@`: Current element trong filter

```bash
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
```

**Giải thích:**
- `.items[0]`: Node đầu tiên
- `.status.addresses`: Array of addresses
- `[?(@.type=="InternalIP")]`: Filter InternalIP
- `.address`: Lấy địa chỉ IP

**Truy cập:** `http://$NODE_IP:$NODE_PORT`

#### 4. LoadBalancer (Option 3)

```bash
kubectl patch svc istio-ingressgateway -n istio-system -p '{"spec":{"type":"LoadBalancer"}}'
```

**Giải thích:**
- Đổi service type sang LoadBalancer
- Cloud provider sẽ tạo load balancer và assign external IP

```bash
while [ -z "$EXTERNAL_IP" ]; do
    echo "Waiting for external IP..."
    EXTERNAL_IP=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    if [ -z "$EXTERNAL_IP" ]; then
        EXTERNAL_IP=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    fi
    [ -z "$EXTERNAL_IP" ] && sleep 5
done
```

**Giải thích:**
- `while [ -z "$EXTERNAL_IP" ]`: Lặp khi EXTERNAL_IP rỗng
- `-z`: Test nếu string rỗng
- Đợi load balancer assign IP hoặc hostname
- `sleep 5`: Đợi 5 giây trước khi check lại

**Lưu ý:** LoadBalancer chỉ hoạt động trên cloud providers (AWS, GCP, Azure).

---

## Script 05: Cleanup

**File:** `scripts/05_cleanup.sh`

**Mục đích:** Xóa Kubeflow khỏi cluster.

### Phân Tích Chi Tiết

#### 1. Confirmation

```bash
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Cleanup cancelled"
    exit 0
fi
```

**Giải thích:**
- Yêu cầu user xác nhận
- Chỉ tiếp tục nếu input = "yes"
- `exit 0`: Thoát với exit code 0 (success, nhưng không làm gì)

#### 2. Manual Cleanup

```bash
kubectl delete namespace kubeflow --timeout=60s 2>/dev/null || kubectl delete namespace kubeflow --force --grace-period=0 2>/dev/null
```

**Giải thích:**
- `kubectl delete namespace`: Xóa namespace và tất cả resources trong đó
- `--timeout=60s`: Timeout sau 60 giây
- `2>/dev/null`: Ẩn lỗi
- `||`: Nếu lệnh đầu fail, chạy lệnh sau
- `--force --grace-period=0`: Force delete ngay lập tức (không đợi graceful shutdown)

**Tại sao cần force delete?**
- Một số resources có finalizers, không thể xóa ngay
- Force delete bỏ qua finalizers

#### 3. Cleanup Using Manifests

```bash
kustomize build example | kubectl delete -f - --timeout=60s 2>/dev/null
```

**Giải thích:**
- `kustomize build example`: Build manifests
- `kubectl delete -f -`: Xóa resources từ manifests
- Xóa theo thứ tự ngược lại với deploy

#### 4. Delete CRDs

```bash
kubectl get crd | grep kubeflow | awk '{print $1}' | xargs kubectl delete crd
```

**Giải thích từng phần:**

1. `kubectl get crd`: Lấy danh sách CRDs
2. `grep kubeflow`: Lọc CRDs liên quan Kubeflow
3. `awk '{print $1}'`: In cột đầu tiên (CRD name)
4. `xargs kubectl delete crd`: Xóa từng CRD

**Pipeline:**
```
get crd → grep → awk → xargs → delete
```

**Ví dụ:**
```
notebooks.kubeflow.org   2024-01-01T00:00:00Z
profiles.kubeflow.org    2024-01-01T00:00:00Z
```
↓ grep kubeflow
```
notebooks.kubeflow.org   2024-01-01T00:00:00Z
profiles.kubeflow.org    2024-01-01T00:00:00Z
```
↓ awk '{print $1}'
```
notebooks.kubeflow.org
profiles.kubeflow.org
```
↓ xargs kubectl delete crd
```
kubectl delete crd notebooks.kubeflow.org
kubectl delete crd profiles.kubeflow.org
```

#### 5. Verify Cleanup

```bash
REMAINING=$(kubectl get pods -A 2>/dev/null | grep -E 'kubeflow|istio|knative|cert-manager|auth' | wc -l)

if [ "$REMAINING" -eq 0 ]; then
    print_success "Cleanup completed successfully! ✨"
else
    print_error "Some pods are still running ($REMAINING pods)"
fi
```

**Giải thích:**
- Đếm pods còn lại
- Nếu = 0 → cleanup thành công
- Nếu > 0 → còn pods đang terminate

---

## 🔑 Các Khái Niệm Quan Trọng

### 1. Kustomize

**Kustomize** là tool để customize Kubernetes manifests mà không cần fork.

**Cấu trúc:**
```
base/
  ├── deployment.yaml
  └── kustomization.yaml

overlays/
  ├── production/
  │   └── kustomization.yaml
  └── development/
      └── kustomization.yaml
```

**kustomization.yaml:**
```yaml
resources:
  - deployment.yaml
patches:
  - replicaCount: 5
```

**Lệnh:**
```bash
kustomize build base/        # Build base
kustomize build overlays/production/  # Build với production config
```

### 2. kubectl apply vs create

- `kubectl create`: Tạo resource mới (fail nếu đã tồn tại)
- `kubectl apply`: Tạo hoặc update (idempotent)

**Idempotent:** Chạy nhiều lần cho cùng kết quả.

### 3. Namespaces

**Namespace** là cách chia cluster thành các phần riêng biệt.

```bash
kubectl get namespaces
kubectl create namespace my-namespace
kubectl get pods -n my-namespace
```

### 4. CRDs (Custom Resource Definitions)

**CRD** định nghĩa custom resources (mở rộng Kubernetes API).

**Ví dụ:**
```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: notebooks.kubeflow.org
spec:
  group: kubeflow.org
  versions:
    - name: v1
  scope: Namespaced
  names:
    plural: notebooks
    singular: notebook
    kind: Notebook
```

Sau khi tạo CRD, có thể tạo Notebook resources:
```yaml
apiVersion: kubeflow.org/v1
kind: Notebook
metadata:
  name: my-notebook
```

### 5. Service Types

- **ClusterIP**: Chỉ accessible trong cluster (default)
- **NodePort**: Expose qua node IP + port (30000-32767)
- **LoadBalancer**: Cloud provider tạo load balancer
- **ExternalName**: Map đến external DNS name

### 6. Pod Lifecycle

```
Pending → ContainerCreating → PodInitializing → Running
                                    ↓
                              (nếu lỗi)
                                    ↓
                            Error/CrashLoopBackOff
```

### 7. Exit Codes

- `0`: Success
- `1`: General error
- `2`: Misuse of shell command
- `127`: Command not found
- `130`: Script terminated by Ctrl+C

### 8. Command Substitution

```bash
VERSION=$(kubectl version --client --short)
```

`$(...)` chạy lệnh và thay thế bằng output.

### 9. Piping và Redirection

```bash
command1 | command2          # Pipe output
command > file               # Redirect stdout
command 2> file              # Redirect stderr
command &> file              # Redirect cả stdout và stderr
command 2>/dev/null          # Discard stderr
```

### 10. Conditional Expressions

```bash
[ -d "$dir" ]                # Test nếu là directory
[ -f "$file" ]               # Test nếu là file
[ -z "$var" ]                # Test nếu string rỗng
[ -n "$var" ]                # Test nếu string không rỗng
[ "$a" = "$b" ]              # String equality
[ "$a" -eq "$b" ]            # Numeric equality
[[ "$str" =~ ^[0-9]+$ ]]     # Regex match
```

---

## 🎓 Best Practices

### 1. Error Handling

```bash
set -e                        # Exit on error
command || true              # Ignore errors
command 2>/dev/null          # Hide errors
```

### 2. Variable Quoting

```bash
"$variable"                   # ✅ Safe (handles spaces)
$variable                     # ❌ Unsafe (breaks on spaces)
```

### 3. Function Parameters

```bash
function_name() {
    local param1=$1
    local param2=$2
    # Use local variables
}
```

### 4. Idempotency

Scripts nên idempotent (chạy nhiều lần an toàn):
- Check trước khi tạo
- Dùng `kubectl apply` thay vì `create`
- Handle resources đã tồn tại

### 5. User Input Validation

```bash
while true; do
    read -p "Enter choice: " choice
    if [[ "$choice" =~ ^[12]$ ]]; then
        break
    fi
    echo "Invalid choice"
done
```

---

## 📝 Tóm Tắt

### Script 01: Prerequisites
- Kiểm tra và cài đặt tools (kubectl, kustomize, jq)
- Verify cluster connection
- Check resources và requirements

### Script 02: Deploy
- Clone Kubeflow manifests
- Deploy từng component theo thứ tự
- 2 methods: Quick (tất cả cùng lúc) hoặc Step-by-step

### Script 03: Status
- Check pods trong các namespaces
- Verify CRDs
- Tính phần trăm deployment
- Detect incomplete deployments

### Script 04: Access
- 3 methods: Port Forward, NodePort, LoadBalancer
- Setup access đến dashboard

### Script 05: Cleanup
- Xóa namespaces và resources
- Option để xóa CRDs
- Verify cleanup thành công

---

## 🔗 Tài Liệu Tham Khảo

- [Kubeflow Documentation](https://www.kubeflow.org/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kustomize Documentation](https://kustomize.io/)
- [Bash Guide](https://www.gnu.org/software/bash/manual/)

---

**Tác giả:** Generated for Platform Lab  
**Ngày:** 2024  
**Version:** 1.0

