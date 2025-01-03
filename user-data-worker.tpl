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

  # Join the cluster using the predefined token
  - kubeadm join 192.168.122.10:6443 --token abcdef.0123456789abcdef --cri-socket=unix:///var/run/crio/crio.sock --discovery-token-unsafe-skip-ca-verification