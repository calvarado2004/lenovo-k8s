# Kubernetes Cluster on Libvirt using OpenTofu

This project deploys a Kubernetes cluster on **Libvirt** using **OpenTofu** (Terraform). It leverages **cloud-init** for provisioning nodes and uses **Cilium** as the CNI (Container Network Interface). The master and worker nodes are provisioned from a base Ubuntu 22.04 image resized to 80GB.

---
### Author

 Carlos Alvarado

## **Prerequisites**

1. **Libvirt Installed**:
    - Ensure Libvirt is installed and running:
      ```bash
      sudo apt update
      sudo apt install -y libvirt-daemon-system libvirt-clients qemu-kvm
      ```

2. **Terraform (OpenTofu) Installed**:
    - Install OpenTofu:
      ```bash
      curl -LO https://github.com/opentofu/tofu/releases/download/v0.x.x/tofu_0.x.x_linux_amd64.zip
      unzip tofu_0.x.x_linux_amd64.zip
      sudo mv tofu /usr/local/bin/
      ```

3. **Helm Installed**:
    - Helm is used to deploy Cilium:
      ```bash
      curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
      ```

---

## **Project Structure**

```plaintext
.
├── cluster.tf                  # Terraform configuration for Libvirt and Kubernetes cluster
├── user-data-master.tpl        # Cloud-init script for the master node
├── user-data-worker.tpl        # Cloud-init script for worker nodes
├── network-config-master.tpl   # Cloud-init network script for the master node
├── network-config-worker.tpl   # Cloud-init network script for worker nodes
```

---

## **Setup and Usage**

### Step 1: Clone the Repository
```bash
git clone <repository-url>
cd <repository-directory>
```

### Step 2: Configure Environment Variables

Set the required environment variables:
```bash
export TF_VAR_ssh_key_path="~/.ssh/id_ed25519.pub"
export TF_VAR_username="carlos"
```

- **`TF_VAR_ssh_key_path`**: Path to your public SSH key.
- **`TF_VAR_username`**: The username to create on the nodes.

### Step 3: Initialize OpenTofu
```bash
tofu init
```

### Step 4: Plan the Deployment
Review the plan to confirm the resources to be created:
```bash
tofu plan
```

### Step 5: Apply the Configuration
Deploy the cluster:
```bash
tofu apply
```

---

## **Cluster Details**

### Master Node
- **Hostname**: `master-0`
- **IP Address**: `192.168.122.10`
- **Resources**:
    - Memory: 16GB
    - vCPUs: 4

### Worker Nodes
- **Hostnames**: `worker-0`, `worker-1`, `worker-2`
- **IP Addresses**:
    - `worker-0`: `192.168.122.11`
    - `worker-1`: `192.168.122.12`
    - `worker-2`: `192.168.122.13`
- **Resources**:
    - Memory: 8GB
    - vCPUs: 2

---

## **Provisioning Notes**

- **Cloud-Init**:
    - The `user-data-master.tpl` script provisions the master node with Kubernetes and Cilium.
    - The `user-data-worker.tpl` script provisions worker nodes to join the cluster.

- **Base Image**:
    - Ubuntu 22.04 cloud image is downloaded and resized to 80GB.

---

## **Post-Deployment Verification**

### Check Node Status
On the master node:
```bash
kubectl get nodes
```

### Check Cilium Status
```bash
cilium status
```

---

## **Cleanup**

To destroy the cluster, run:
```bash
tofu destroy
```

---

## **Known Issues**

1. **Libvirt Permissions**:
    - Ensure the user running OpenTofu has sufficient permissions to manage Libvirt resources.

---

Feel free to raise issues or contribute to this project. Enjoy building your Kubernetes cluster with OpenTofu and Libvirt! 🚀