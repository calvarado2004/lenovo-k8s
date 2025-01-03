resource "null_resource" "customize_ubuntu_image" {
  provisioner "local-exec" {
    command = <<EOT
    IMAGE_DIR="/var/lib/libvirt/images"
    IMAGE_NAME="ubuntu-24.04.qcow2"
    IMAGE_PATH="$IMAGE_DIR/$IMAGE_NAME"

    IMAGE_URL="https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"

    mkdir -p "$IMAGE_DIR"
    IMAGE_PATH="$IMAGE_DIR/$IMAGE_NAME"

    # Download the image if it does not exist
    if [ ! -f "$IMAGE_PATH" ]; then
      echo "Downloading base image..."
      wget -O "$IMAGE_PATH" "$IMAGE_URL"
    fi

    # Resize the image to 80GB
    if [ -f "$IMAGE_PATH" ]; then
      echo "Checking current size..."
      CURRENT_SIZE=$(qemu-img info --output=json "$IMAGE_PATH" | jq -r '.["virtual-size"]' || echo "0")
      DESIRED_SIZE=$((80 * 1024 * 1024 * 1024)) # 80GB

      if [ "$CURRENT_SIZE" -lt "$DESIRED_SIZE" ]; then
        echo "Resizing image to 80GB..."
        qemu-img resize "$IMAGE_PATH" 80G
      else
        echo "Image is already the desired size or larger."
      fi
    else
      echo "Error: Image file not found after download."
      exit 1
    fi

    # Customize ubuntu image and install CRI-O and Kubeadm
    virt-customize -a "$IMAGE_PATH" \
      --run-command "growpart /dev/sda 1 && resize2fs /dev/sda1" \
      --run-command "touch /var/log/cloud-init-output.log" \
      --run-command "echo 'kernel.printk = 7 4 1 7' >> /etc/sysctl.conf" \
      --run-command "sysctl -p" \
      --run-command "swapoff -a" \
      --run-command "sed -i '/ swap / s/^/#/' /etc/fstab" \
      --run-command "cat <<EOF | tee /etc/sysctl.d/99-kubernetes-cri.conf
    net.bridge.bridge-nf-call-iptables  = 1
    net.ipv4.ip_forward                 = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    EOF" \
      --run-command "mkdir -p /etc/apt/keyrings" \
      --run-command "curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key | gpg --batch --yes --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg" \
      --run-command "echo 'deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /' | tee /etc/apt/sources.list.d/cri-o.list" \
      --run-command "apt-get update" \
      --run-command "apt-get install -y wget fuse-overlayfs cri-o" \
      --run-command "apt-get install -y apt-transport-https ca-certificates curl" \
      --run-command "curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --batch --yes --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg" \
      --run-command "echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list" \
      --run-command "apt-get update" \
      --run-command "apt-get install -y kubelet kubeadm kubectl" \
      --run-command "apt-mark hold kubelet kubeadm kubectl" \
      --run-command "apt-get update" \
      --run-command "apt-get upgrade -y"

    EOT
  }
}

output "base_image_path" {
  value = "/var/lib/libvirt/images/ubuntu-24.04.qcow2"
}

