terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.8.1"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

variable "ssh_key_path" {
  description = "Path to the SSH public key"
  type        = string
}

variable "username" {
  description = "Username to create on the nodes"
  type        = string
}

# Network Configuration
resource "libvirt_network" "k8s_network" {
  name   = "k8s_network"
  domain = "k8s.local"
  mode   = "nat"
  addresses = ["192.168.122.0/24"]
  autostart = true
}

# Base Ubuntu Image
module "base_image" {
  source = "./modules/base_image"
}

resource "libvirt_volume" "ubuntu_image" {
  depends_on = [module.base_image]
  name       = "ubuntu-24.04.qcow2"
  pool       = "default"
  source     = module.base_image.base_image_path
  format     = "qcow2"
}

# Master Node Volume
resource "libvirt_volume" "master_root" {
  name           = "master-root.qcow2"
  pool           = "default"
  format         = "qcow2"
  base_volume_id = libvirt_volume.ubuntu_image.id
}

# Worker Node Volumes
resource "libvirt_volume" "worker_root" {
  count          = 3
  name           = "worker-${count.index}-root.qcow2"
  pool           = "default"
  format         = "qcow2"
  base_volume_id = libvirt_volume.ubuntu_image.id
}

# Cloud-Init for Master Node
data "template_file" "master_user_data" {
  template = file("${path.module}/user-data-master.tpl")
  vars = {
    ssh_authorized_keys = file(var.ssh_key_path)
    username            = var.username
    hostname            = "master-0"
    k8s_token           = "abcdef.0123456789abcdef"
    network_cidr        = "192.168.0.0/16"
  }
}

resource "libvirt_cloudinit_disk" "master_init" {
  name      = "master-init.iso"
  pool      = "default"
  user_data = data.template_file.master_user_data.rendered
}

# Cloud-Init for Worker Nodes
data "template_file" "worker_user_data" {
  count = 3
  template = file("${path.module}/user-data-worker.tpl")
  vars = {
    ssh_authorized_keys = file(var.ssh_key_path)
    username            = var.username
    hostname            = "worker-${count.index}"
    master_ip           = "192.168.122.10"
    k8s_token           = "abcdef.0123456789abcdef"
  }
}

resource "libvirt_cloudinit_disk" "worker_init" {
  count     = 3
  name      = "worker-init-${count.index}.iso"
  pool      = "default"
  user_data = data.template_file.worker_user_data[count.index].rendered
}

# Define Master Node
resource "libvirt_domain" "master" {
  name   = "master-0-lenovo-k8s"
  memory = 16384
  vcpu   = 4

  disk {
    volume_id = libvirt_volume.master_root.id
  }

  cloudinit = libvirt_cloudinit_disk.master_init.id

  network_interface {
    network_id = libvirt_network.k8s_network.id
    addresses  = ["192.168.122.10"]
  }

  console {
    type        = "pty"
    target_port = "0"
  }
}

# Wait for Master Node to Initialize
resource "null_resource" "wait_for_master" {
  depends_on = [libvirt_domain.master]

  provisioner "local-exec" {
    command = "echo 'Waiting 5 minutes for master node initialization...' && sleep 300"
  }
}

# Additional Block Storage for Worker Nodes for Portworx
resource "libvirt_volume" "worker_block_200gb" {
  count          = 3
  name           = "worker-${count.index}-block-200gb.qcow2"
  pool           = "default"
  format         = "qcow2"
  size           = 214748364800 # size in bytes, known issue with libvirt_volume
}

# Additional Block Storage drive for Portworx KVDB
resource "libvirt_volume" "worker_block_12gb" {
  count          = 3
  name           = "worker-${count.index}-block-12gb.qcow2"
  pool           = "default"
  format         = "qcow2"
  size           = 12884901888 # size in bytes, known issue with libvirt_volume
}

# Define Worker Nodes with Additional Disks
resource "libvirt_domain" "worker" {
  count  = 3
  depends_on = [null_resource.wait_for_master]

  name   = "worker-${count.index}-lenovo-k8s"
  memory = 16384
  vcpu   = 4

  disk {
    volume_id = libvirt_volume.worker_root[count.index].id
  }

  # Attach the 200GB block storage
  disk {
    volume_id = libvirt_volume.worker_block_200gb[count.index].id
  }

  # Attach the 12GB block storage
  disk {
    volume_id = libvirt_volume.worker_block_12gb[count.index].id
  }

  cloudinit = libvirt_cloudinit_disk.worker_init[count.index].id

  network_interface {
    network_id = libvirt_network.k8s_network.id
    addresses  = ["192.168.122.${count.index + 11}"]
  }

  console {
    type        = "pty"
    target_port = "0"
  }
}
