#cloud-config


datasource_list: [ NoCloud, None ]

users:
  - name: ${username}
    ssh_authorized_keys:
      - ${ssh_authorized_keys}
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: sudo
    shell: /bin/bash

runcmd:

  # Logging visibility
  - touch /var/log/cloud-init-output.log
  - echo "kernel.printk = 7 4 1 7" >> /etc/sysctl.conf
  - sysctl -p
  - tail -F /var/log/cloud-init-output.log > /dev/kmsg &

  # Disable swap
  - swapoff -a
  - sed -i '/ swap / s/^/#/' /etc/fstab

  # set hostname
  - hostnamectl set-hostname ${hostname}-lenovo-k8s

  # Load required kernel modules
  - modprobe overlay
  - modprobe br_netfilter

  # Set up sysctl parameters
  - |
    cat <<EOF | tee /etc/sysctl.d/99-kubernetes-cri.conf
    net.bridge.bridge-nf-call-iptables  = 1
    net.ipv4.ip_forward                 = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    EOF
  - sysctl --system

  # Install CRI-O
  - curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
  - mkdir -p /etc/apt/keyrings/
  - echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" | tee /etc/apt/sources.list.d/cri-o.list
  - apt-get update
  - apt-get install -y fuse-overlayfs cri-o
  - systemctl enable crio --now

  # Install Kubernetes components
  - apt-get install -y apt-transport-https ca-certificates curl gpg
  - curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  - echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
  - apt-get update
  - apt-get install -y kubelet kubeadm kubectl
  - apt-mark hold kubelet kubeadm kubectl

  # Initialize the Kubernetes cluster with a predefined token
  - kubeadm init --pod-network-cidr=192.168.0.0/16 --cri-socket=unix:///var/run/crio/crio.sock --token abcdef.0123456789abcdef

  # Configure kubectl for non-root user
  - mkdir -p /home/${username}/.kube
  - cp -i /etc/kubernetes/admin.conf /home/${username}/.kube/config
  - chown ${username}:${username} /home/${username}/.kube/config

  # Install Cilium CLI
  - curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/download/v0.16.22/cilium-linux-amd64.tar.gz
  - tar -xzvf cilium-linux-amd64.tar.gz
  - mv cilium /usr/local/bin/

  # Deploy Cilium with Cilium CLI
  - cilium install --namespace kube-system --kubeconfig /home/${username}/.kube/config
  - kubectl get nodes -o wide --kubeconfig /home/${username}/.kube/config
  - echo Wait 3 minutes for Cilium and K8s nodes to be ready...
  - sleep 180
  - cilium status --kubeconfig /home/${username}/.kube/config
  - kubectl get nodes -o wide --kubeconfig /home/${username}/.kube/config
  - echo Wait 3 minutes more for Cilium and K8s nodes to be ready...
  - sleep 180
  - cilium status --kubeconfig /home/${username}/.kube/config
  - kubectl get nodes -o wide --kubeconfig /home/${username}/.kube/config