# Fix: 404 Not Found khi truy cập JupyterLab

## 🐛 Vấn đề

**Symptom:**
- Port-forward chạy thành công
- Truy cập `http://localhost:8888` → **404: Not Found**
- Token không tìm được

**Terminal Output:**
```
Forwarding from 127.0.0.1:8888 -> 8888
Handling connection for 8888
...
404 GET / (d43fc56b9dc0453491fbac3af8101ffb@127.0.0.1)
```

**Browser Error:**
```
404 : Not Found
You are requesting a page that does not exist!
```

---

## 🔍 Root Cause

### 1. **JupyterLab dùng Path-based Routing**

JupyterLab trong Notebook Controller **KHÔNG** serve ở root path `/`.

**URL đúng:**
```
http://localhost:8888/notebook/<namespace>/<notebook-name>/lab
```

**Ví dụ:**
```
http://localhost:8888/notebook/test-notebook/tensorflow-notebook/lab
```

### 2. **Logs từ Pod:**

```bash
kubectl logs -n test-notebook tensorflow-notebook-0
```

**Output:**
```
[I 2025-12-25 08:27:31.367 ServerApp] http://127.0.0.1:8888/notebook/test-notebook/tensorflow-notebook/lab
```

→ JupyterLab đang serve ở path đầy đủ, không phải root `/`.

### 3. **Token không có trong output**

- JupyterLab mới không hiển thị token trong `jupyter notebook list`
- Token có thể không cần thiết nếu đã authenticated qua kubectl

---

## ✅ Solution

### Fix 1: Sửa URL trong Script

**Code cũ:**
```bash
print_success "Notebook is accessible at: http://localhost:$PORT"
```

**Code mới:**
```bash
# Build notebook URL path (JupyterLab uses path-based routing)
NOTEBOOK_PATH="/notebook/$NOTEBOOK_NAMESPACE/$NOTEBOOK_NAME/lab"
NOTEBOOK_URL="http://localhost:$PORT$NOTEBOOK_PATH"
print_success "Notebook is accessible at: $NOTEBOOK_URL"
```

### Fix 2: Cải thiện Token Extraction

Script thử nhiều phương pháp:

```bash
# Method 1: jupyter notebook list (old Jupyter)
TOKEN=$(kubectl exec ... -- jupyter notebook list | grep -oP 'token=\K[^\s]+')

# Method 2: jupyter server list (new JupyterLab)
TOKEN=$(kubectl exec ... -- jupyter server list | grep -oP 'token=\K[^\s]+')

# Method 3: Extract from logs
TOKEN=$(kubectl logs ... | grep -oP 'token[=:]\s*\K[^\s,]+')
```

### Fix 3: Hiển thị Instructions rõ ràng

Script hiện tại hiển thị:
- URL đúng với path đầy đủ
- Hướng dẫn lấy token nếu cần
- Note về authentication

---

## 🧪 Testing

### Test với URL đúng:

```bash
# 1. Start port-forward
./scripts/08_access_notebook.sh tensorflow-notebook test-notebook

# 2. Trong browser, truy cập:
http://localhost:8888/notebook/test-notebook/tensorflow-notebook/lab
```

### Verify từ logs:

```bash
# Check logs để confirm URL
kubectl logs -n test-notebook tensorflow-notebook-0 | grep "http://"

# Output:
# http://127.0.0.1:8888/notebook/test-notebook/tensorflow-notebook/lab
```

---

## 📝 JupyterLab URL Pattern

### Structure:
```
http://<host>:<port>/notebook/<namespace>/<notebook-name>/lab
```

### Examples:
```
# Development
http://localhost:8888/notebook/default/my-notebook/lab

# Production (with ingress)
https://notebook.example.com/notebook/prod/data-science-notebook/lab
```

### Alternative paths:
- `/lab` - JupyterLab interface
- `/tree` - Classic Jupyter Notebook interface (if available)

---

## 🔑 Token Authentication

### Option 1: Token không cần thiết
- Nếu đã authenticated qua kubectl
- Notebook Controller có thể handle auth tự động

### Option 2: Lấy token từ logs
```bash
kubectl logs -n test-notebook tensorflow-notebook-0 | grep -i token
```

### Option 3: Extract từ pod environment
```bash
kubectl exec -n test-notebook tensorflow-notebook-0 -- env | grep -i jupyter
```

### Option 4: Sử dụng trong URL
```
http://localhost:8888/notebook/test-notebook/tensorflow-notebook/lab?token=<TOKEN>
```

---

## 🎯 Complete Workflow

### Step 1: Deploy Notebook
```bash
./scripts/07_create_notebook.sh
```

### Step 2: Wait for Ready
```bash
./scripts/09_check_notebook_status.sh
```

### Step 3: Access Notebook
```bash
./scripts/08_access_notebook.sh tensorflow-notebook test-notebook
```

**Output sẽ hiển thị:**
```
========================================
Access Information
========================================
Notebook URL: http://localhost:8888/notebook/test-notebook/tensorflow-notebook/lab

========================================
Port Forward Started
========================================

✓ Notebook is accessible at: http://localhost:8888/notebook/test-notebook/tensorflow-notebook/lab
```

### Step 4: Open Browser
- Copy URL và paste vào browser
- ✅ Không còn 404 error!

---

## 🔧 Troubleshooting

### Issue 1: Vẫn 404 sau khi fix
**Check:**
```bash
# Verify path đúng
echo "/notebook/test-notebook/tensorflow-notebook/lab"

# Check pod logs
kubectl logs -n test-notebook tensorflow-notebook-0 | grep "http://"
```

### Issue 2: Token required nhưng không tìm được
**Solution:**
```bash
# Check logs manually
kubectl logs -n test-notebook tensorflow-notebook-0

# Or exec into pod
kubectl exec -n test-notebook tensorflow-notebook-0 -- jupyter server list
```

### Issue 3: Connection refused
**Check:**
- Port-forward đang chạy? (không bị Ctrl+C)
- Pod đang Running?
- Port 8888 không bị conflict?

---

## 📚 Related Documentation

- **Notebook Controller**: Xử lý routing và path-based access
- **JupyterLab**: Path structure và URL pattern
- **Kubernetes Port Forward**: Forward traffic đến pod

---

## ✨ Summary

**Vấn đề:**
- ❌ Truy cập root path `/` → 404
- ✅ Cần path đầy đủ: `/notebook/<namespace>/<notebook-name>/lab`

**Fix:**
- Script build đúng URL với path
- Hiển thị instructions rõ ràng
- Cải thiện token extraction

**Result:**
- ✅ URL đúng được hiển thị
- ✅ User biết chính xác path cần truy cập
- ✅ Không còn 404 error!

