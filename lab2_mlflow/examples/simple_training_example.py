"""
Example: Simple ML training with MLflow tracking

This example demonstrates a complete ML workflow with MLflow tracking:
- Training a simple model
- Logging parameters, metrics, and artifacts
- Model versioning
"""

import mlflow
import mlflow.sklearn
import numpy as np
from sklearn.datasets import make_classification
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score
import sys

# MLflow Server URL
MLFLOW_TRACKING_URI = "http://mlflow-service.mlflow.svc.cluster.local:5000"

# Set tracking URI
mlflow.set_tracking_uri(MLFLOW_TRACKING_URI)

# Experiment name
EXPERIMENT_NAME = "simple-classification"

print("=" * 60)
print("Simple ML Training with MLflow Tracking")
print("=" * 60)

# Set experiment
mlflow.set_experiment(EXPERIMENT_NAME)

# Generate sample data
print("\n[1] Generating sample dataset...")
X, y = make_classification(
    n_samples=1000,
    n_features=20,
    n_informative=15,
    n_redundant=5,
    n_classes=2,
    random_state=42
)
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42
)
print(f"   Training samples: {X_train.shape[0]}")
print(f"   Test samples: {X_test.shape[0]}")

# Training parameters
params = {
    "n_estimators": 100,
    "max_depth": 10,
    "min_samples_split": 2,
    "min_samples_leaf": 1,
    "random_state": 42
}

print(f"\n[2] Training RandomForest with parameters: {params}")

# Start MLflow run
with mlflow.start_run(run_name="random-forest-baseline") as run:
    # Log parameters
    print("\n[3] Logging parameters...")
    for key, value in params.items():
        mlflow.log_param(key, value)
    
    # Train model
    print("\n[4] Training model...")
    model = RandomForestClassifier(**params)
    model.fit(X_train, y_train)
    
    # Make predictions
    print("\n[5] Making predictions...")
    y_pred = model.predict(X_test)
    
    # Calculate metrics
    print("\n[6] Calculating metrics...")
    accuracy = accuracy_score(y_test, y_pred)
    precision = precision_score(y_test, y_pred)
    recall = recall_score(y_test, y_pred)
    f1 = f1_score(y_test, y_pred)
    
    # Log metrics
    mlflow.log_metric("accuracy", accuracy)
    mlflow.log_metric("precision", precision)
    mlflow.log_metric("recall", recall)
    mlflow.log_metric("f1_score", f1)
    
    print(f"   Accuracy:  {accuracy:.4f}")
    print(f"   Precision: {precision:.4f}")
    print(f"   Recall:    {recall:.4f}")
    print(f"   F1 Score:  {f1:.4f}")
    
    # Log model
    print("\n[7] Logging model...")
    mlflow.sklearn.log_model(
        model,
        "model",
        registered_model_name="RandomForestClassifier"
    )
    print(f"   ✅ Model logged and registered")
    
    # Log additional artifacts
    print("\n[8] Logging artifacts...")
    feature_importance = model.feature_importances_
    with open("feature_importance.txt", "w") as f:
        f.write("Feature Importances:\n")
        for i, importance in enumerate(feature_importance[:10]):  # Top 10
            f.write(f"Feature {i}: {importance:.4f}\n")
    mlflow.log_artifact("feature_importance.txt")
    print(f"   ✅ Artifacts logged")

print("\n" + "=" * 60)
print("✅ Training completed successfully!")
print("=" * 60)
print(f"\nRun Information:")
print(f"  Run ID: {run.info.run_id}")
print(f"  Experiment: {EXPERIMENT_NAME}")
print(f"  Model: RandomForestClassifier")
print(f"\nView in MLflow UI:")
print(f"  {MLFLOW_TRACKING_URI}")




