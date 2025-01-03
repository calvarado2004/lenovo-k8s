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

  # set hostname
  - hostnamectl set-hostname ${hostname}-lenovo-k8s
  - sysctl --system
  - touch /var/log/cloud-init-output.log
  - tail -F /var/log/cloud-init-output.log > /dev/kmsg &

  # start crio
  - modprobe overlay
  - modprobe br_netfilter
  - systemctl enable crio --now

  # Initialize the Kubernetes cluster with a predefined token
  - kubeadm init --pod-network-cidr=192.168.0.0/16 --cri-socket=unix:///var/run/crio/crio.sock --token abcdef.0123456789abcdef

  # Configure kubectl for non-root user
  - mkdir -p /home/${username}/.kube
  - cp -i /etc/kubernetes/admin.conf /home/${username}/.kube/config
  - chown ${username}:${username} /home/${username}/.kube/config

  # Download Cilium CLI
  - curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/download/v0.16.22/cilium-linux-amd64.tar.gz
  - tar xzvf cilium-linux-amd64.tar.gz
  - mv cilium /usr/local/bin/

  # Deploy Cilium on K8s
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