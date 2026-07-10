terraform {
  required_version = ">= 1.5.0"

  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = ">= 0.7.0, < 0.9.0" # 0.9.x is a schema rewrite; pin to classic API
    }
  }
}

provider "libvirt" {
  uri = var.libvirt_uri
}

# --- Pool

resource "libvirt_pool" "ssd" {
  name = var.pool_ssd
  type = "dir"
  target {
    path = var.pool_ssd_path
  }
}

resource "libvirt_pool" "hdd" {
  name = var.pool_hdd
  type = "dir"
  target {
    path = var.pool_hdd_path
  }
}

# --- Network

resource "libvirt_network" "mgmt" {
  name      = var.net_mgmt
  addresses = ["10.10.250.0/24"]
  autostart = true
  dhcp {
    enabled = true
  }
}

resource "libvirt_network" "ceph_public" {
  name      = var.net_ceph_public
  mode      = "none"
  autostart = true
  addresses = ["10.10.2.0/24"]
}

resource "libvirt_network" "os_internal" {
  name      = var.net_os_internal
  mode      = "none"
  autostart = true
  addresses = ["10.10.3.0/24"]
}

resource "libvirt_network" "os_external" {
  name      = var.net_os_external
  mode      = "none"
  autostart = true
  addresses = ["10.10.4.0/24"]
}

resource "libvirt_network" "os_tenant" {
  name      = var.net_os_tenant
  mode      = "nat"
  autostart = true
  addresses = ["10.10.5.0/24"]
  dhcp {
    enabled = false
  }
}

resource "libvirt_network" "ceph_cluster" {
  name      = var.net_ceph_cluster
  mode      = "none"
  autostart = true
  addresses = ["10.10.6.0/24"]
}

# --- Base cloud image -------------------------------------------------------
# Pull the official Ubuntu 24.04 (Noble) cloud image once as the immutable
# backing volume. Each node disk is a copy-on-write clone of this base.
resource "libvirt_volume" "base" {
  name   = "${var.name_prefix}-base.qcow2"
  pool   = libvirt_pool.ssd.name
  source = var.base_image_url
  format = "qcow2"
}

resource "libvirt_volume" "root" {
  for_each = var.nodes

  name           = "${var.name_prefix}-${each.key}-root.qcow2"
  pool           = libvirt_pool.ssd.name
  base_volume_id = libvirt_volume.base.id
  size           = var.disk_size_root
  format         = "qcow2"
}

# --- Additional block storage

resource "libvirt_volume" "osd_ssd_5g" {
  for_each = { for k, v in var.nodes : k => v if v.role == "ceph" }

  name   = "${var.name_prefix}-${each.key}-osd-ssd1.qcow2"
  pool   = libvirt_pool.ssd.name
  size   = var.disk_size_ssd_5g
  format = "qcow2"
}

resource "libvirt_volume" "osd_ssd_10g" {
  for_each = { for k, v in var.nodes : k => v if v.role == "ceph" }

  name   = "${var.name_prefix}-${each.key}-osd-ssd2.qcow2"
  pool   = libvirt_pool.ssd.name
  size   = var.disk_size_ssd_10g
  format = "qcow2"
}

resource "libvirt_volume" "osd_hdd_50g" {
  for_each = { for k, v in var.nodes : k => v if v.role == "ceph" }

  name   = "${var.name_prefix}-${each.key}-osd-hdd1.qcow2"
  pool   = libvirt_pool.hdd.name
  size   = var.disk_size_hdd_50g
  format = "qcow2"
}

# --- cloud-init -------------------------------------------------------------
# Deliberately vanilla: we only inject an SSH key so we can log in
resource "libvirt_cloudinit_disk" "init" {
  for_each = var.nodes

  name = "${var.name_prefix}-${each.key}-cloudinit.iso"
  pool = libvirt_pool.ssd.name

  user_data = templatefile(
    each.value.role == "openstack" ? "${path.module}/cloud-init/openstack/user-data.yaml" : "${path.module}/cloud-init/ceph/user-data.yaml",
    {
      hostname       = each.key
      ssh_username   = var.ssh_username
      ssh_public_key = trimspace(file(pathexpand(var.ssh_public_key)))
    }
  )

  network_config = templatefile(
    each.value.role == "openstack" ? "${path.module}/cloud-init/openstack/net-config.yaml" : "${path.module}/cloud-init/ceph/net-config.yaml",
    {
      ip_idx = each.value.role == "ceph" ? tonumber(replace(each.key, "ceph-node", "")) + 20 : 0 # we will not use it in openstack
    }
  )
}

# --- Domains (the VMs) ------------------------------------------------------
resource "libvirt_domain" "vm" {
  for_each = var.nodes

  name      = "${var.name_prefix}-${each.key}"
  memory    = each.value.memory_mib
  vcpu      = each.value.vcpu
  cloudinit = libvirt_cloudinit_disk.init[each.key].id

  cpu {
    mode = "host-passthrough"
  }

  network_interface {
    network_name   = var.net_mgmt
    wait_for_lease = true
  }

  network_interface {
    network_name = var.net_ceph_public
  }

  dynamic "network_interface" {
    for_each = each.value.role == "openstack" ? [1] : []
    content {
      network_name = var.net_os_internal
    }
  }

  dynamic "network_interface" {
    for_each = each.value.role == "openstack" ? [1] : []
    content {
      network_name = var.net_os_external
    }
  }

  dynamic "network_interface" {
    for_each = each.value.role == "openstack" ? [1] : []
    content {
      network_name = var.net_os_tenant
    }
  }

  dynamic "network_interface" {
    for_each = each.value.role == "ceph" ? [1] : []
    content {
      network_name = var.net_ceph_cluster
    }
  }

  disk {
    volume_id = libvirt_volume.root[each.key].id
  }

  dynamic "disk" {
    for_each = each.value.role == "ceph" ? [1] : []
    content {
      volume_id = libvirt_volume.osd_ssd_5g[each.key].id
    }
  }

  dynamic "disk" {
    for_each = each.value.role == "ceph" ? [1] : []
    content {
      volume_id = libvirt_volume.osd_ssd_10g[each.key].id
    }
  }

  dynamic "disk" {
    for_each = each.value.role == "ceph" ? [1] : []
    content {
      volume_id = libvirt_volume.osd_hdd_50g[each.key].id
    }
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }

  depends_on = [
    libvirt_network.mgmt,
    libvirt_network.os_internal,
    libvirt_network.os_external,
    libvirt_network.os_tenant,
    libvirt_network.ceph_public,
    libvirt_network.ceph_cluster
  ]
}
