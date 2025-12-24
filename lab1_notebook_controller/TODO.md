# Lab 1: Kubeflow Notebook Controller Deployment and Testing

## Task 1: Deploy and Test Full Kubeflow
- Deploy Kubeflow on an existing Kubernetes cluster.
- Verify Kubeflow is running correctly (pods healthy, dashboard accessible).
- Create and run a Notebook from Kubeflow.
- Test workload execution inside the Notebook (CPU).
- (Optional) Test GPU workload if the cluster has GPU nodes.

## Task 2: Remove Kubeflow and Deploy Notebook Controller Only
- Uninstall and clean up the full Kubeflow deployment.
- Deploy only the Kubeflow Notebook Controller on Kubernetes.
- Install required CRDs, RBAC, and controller components.
- Create a Notebook resource using YAML.
- Access the Notebook and run workloads successfully.
- (Optional) Verify the Notebook can run GPU workloads.

## Task 3: Demo and Explanation (Optional)
- Prepare a simple demo showing Notebook creation and execution.
- Demonstrate access to the Notebook and workload execution.
- Explain how the Notebook Controller works:
  - What the Notebook CRD is.
  - How the controller creates Pods, Services, and Volumes.
  - How GPU scheduling works (if applicable).
