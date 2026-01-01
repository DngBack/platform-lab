"""
Example: Test MLflow connection from notebook

This script demonstrates how to connect to MLflow Server from a notebook
running in Kubernetes cluster.
"""

import mlflow
import sys

# MLflow Server URL in Kubernetes
# Format: http://<service-name>.<namespace>.svc.cluster.local:<port>
MLFLOW_TRACKING_URI = "http://mlflow-service.mlflow.svc.cluster.local:5000"

print("=" * 60)
print("Testing MLflow Connection")
print("=" * 60)

# Set tracking URI
print(f"\n[1] Setting MLflow tracking URI to: {MLFLOW_TRACKING_URI}")
mlflow.set_tracking_uri(MLFLOW_TRACKING_URI)

# Test connection
print("\n[2] Testing connection to MLflow Server...")
try:
    # Try to list experiments (this will fail if server is not accessible)
    experiments = mlflow.search_experiments()
    print(f"✅ Successfully connected to MLflow Server!")
    print(f"   Found {len(experiments)} experiment(s)")
except Exception as e:
    print(f"❌ Failed to connect to MLflow Server")
    print(f"   Error: {str(e)}")
    print("\nTroubleshooting:")
    print("  1. Check if MLflow Server is running: kubectl get pods -n mlflow")
    print("  2. Check service: kubectl get svc -n mlflow")
    print("  3. Try ping from notebook: ping mlflow-service.mlflow.svc.cluster.local")
    sys.exit(1)

# Create or get experiment
EXPERIMENT_NAME = "test-experiment"
print(f"\n[3] Creating/Getting experiment: {EXPERIMENT_NAME}")
mlflow.set_experiment(EXPERIMENT_NAME)

# Start a test run
print(f"\n[4] Starting a test run...")
with mlflow.start_run(run_name="connection-test") as run:
    # Log some test parameters
    mlflow.log_param("test_param", "connection_test")
    mlflow.log_param("python_version", sys.version.split()[0])
    
    # Log some test metrics
    mlflow.log_metric("test_accuracy", 0.95)
    mlflow.log_metric("test_loss", 0.05)
    
    print(f"   Run ID: {run.info.run_id}")
    print(f"   Experiment ID: {run.info.experiment_id}")
    
    # Log a test artifact (text file)
    with open("test_artifact.txt", "w") as f:
        f.write("This is a test artifact from MLflow connection test")
    mlflow.log_artifact("test_artifact.txt")
    print(f"   ✅ Logged test artifact")

print("\n" + "=" * 60)
print("✅ MLflow connection test completed successfully!")
print("=" * 60)
print(f"\nYou can view this run in MLflow UI:")
print(f"  Internal: {MLFLOW_TRACKING_URI}")
print(f"  Or port-forward: kubectl port-forward -n mlflow svc/mlflow-service 5000:5000")
print(f"  Then open: http://localhost:5000")

