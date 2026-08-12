output "nodes" {
  description = "Map of node name => leased IPv4 address."
  value = {
    for k, v in libvirt_domain.vm :
    k => try(v.network_interface[0].addresses[0], "No IP available yet.")
  }
}

output "ssh_commands" {
  description = "Ready-to-run SSH commands for each node."
  value = {
    for k, v in libvirt_domain.vm :
    k => try("ssh ${var.ssh_username}@${v.network_interface[0].addresses[0]}", "No IP available yet.")
  }
}

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.tftpl", {
    openstack_nodes = [
      for vm in libvirt_domain.vm : {
        name        = trimprefix(vm.name, "${var.name_prefix}-")
        mgmt_ip     = try(vm.network_interface[0].addresses[0], "No IP available yet.")
        external_ip = try(vm.network_interface[3].addresses[0], "No IP available yet.")
        internal_ip = try(vm.network_interface[2].addresses[0], "No IP available yet.")
      } if length(regexall(".*openstack.*", vm.name)) > 0
    ]

    ceph_nodes = [
      for vm in libvirt_domain.vm : {
        name        = trimprefix(vm.name, "${var.name_prefix}-")
        mgmt_ip     = try(vm.network_interface[0].addresses[0], "No IP available yet.")
        public_ip   = try(vm.network_interface[1].addresses[0], "No IP available yet.")
        internal_ip = try(vm.network_interface[2].addresses[0], "No IP available yet.")
        cluster_ip  = try(vm.network_interface[3].addresses[0], "No IP available yet.")
      } if length(regexall(".*ceph.*", vm.name)) > 0
    ]
  })

  filename = "${path.module}/../ansible/inventory.ini"
}
