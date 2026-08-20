variable "libvirt_uri" {
  description = "Libvirt connection URI for the local KVM host."
  type        = string
  default     = "qemu:///system"
}

variable "name_prefix" {
  description = "Prefix for libvirt domain and volume names."
  type        = string
  default     = "ubuntu"
}

variable "nodes" {
  description = "Map of node name => {vcpu, memory_mib} to provision. Role for NIC/disk assignment."
  type = map(object({
    vcpu       = number
    memory_mib = number
    role       = string
  }))
  default = {
    "ceph-node1" = { vcpu = 4, memory_mib = 4096, role = "ceph" }
    "ceph-node2" = { vcpu = 4, memory_mib = 4096, role = "ceph" }
    "ceph-node3" = { vcpu = 4, memory_mib = 4096, role = "ceph" }
    "ceph-node4" = { vcpu = 4, memory_mib = 4096, role = "ceph" }
    "ceph-node5" = { vcpu = 4, memory_mib = 4096, role = "ceph" }
    "ceph-node6" = { vcpu = 4, memory_mib = 4096, role = "ceph" }
  }
}

// Pool

variable "pool_ssd" {
  description = "Pool placed on SSD."
  type        = string
  default     = "default" # Main pool
}

variable "pool_ssd_path" {
  description = "SSD Pool path."
  type        = string
  default     = "/var/lib/libvirt/images"
}

variable "pool_hdd" {
  description = "Pool placed on HDD."
  type        = string
  default     = "hdd-pool"
}

variable "pool_hdd_path" {
  description = "HDD Pool path."
  type        = string
  default     = "/mnt/hdd-linux/vms-storage"
}

// Disk size

variable "disk_size_root" {
  description = "Root disk size in bytes (default 40 GiB)."
  type        = number
  default     = 42949672960
}

# This disk is mainly used for bluestore/wal
variable "disk_size_ssd_5g" {
  description = "SSD disk size in bytes (5 GiB)."
  type        = number
  default     = 5368709120
}

variable "disk_size_ssd_25g" {
  description = "SSD disk size in bytes (25 GiB)."
  type        = number
  default     = 26843545600
}

variable "disk_size_hdd_50g" {
  description = "HDD disk size in bytes (50 GiB)."
  type        = number
  default     = 53687091200
}

variable "disk_size_hdd_75g" {
  description = "HDD disk size in bytes (75 GiB)."
  type        = number
  default     = 80530636800
}
// SSH +  image

variable "base_image_url" {
  description = "Ubuntu 24.04 (Noble) cloud image URL."
  type        = string
  default     = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
}

variable "ssh_username" {
  description = "Default login user provisioned via cloud-init."
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_key" {
  description = "Path to the SSH public key injected into the VMs for passwordless login."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

// Network

variable "net_mgmt" {
  description = "Management Network."
  type        = string
  default     = "mgmt-net"
}

variable "net_ceph_public" {
  description = "Public Network for Ceph."
  type        = string
  default     = "ceph-public-net"
}

variable "net_ceph_cluster" {
  description = "Cluster Network for Ceph."
  type        = string
  default     = "ceph-cluster-net"
}
