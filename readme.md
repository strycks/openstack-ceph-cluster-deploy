Management Network: `10.10.250.0/24` dhcp  
Ceph Public Network: `10.10.2.10/24 (Openstack) 10.10.2.{id + 20}/24 (Ceph)`  
Ceph Cluster Network: `10.10.6.{id + 20}/24 (Ceph)`  
OpenStack Internal Network: `10.10.3.10/24`  
OpenStack External Network: `10.10.4.10/24`  
OpenStack Neutron Network: `10.10.5.0/24` Neutron-managed

Remember to turn off CoW on image pools:
`sudo chattr +C /var/lib/libvirt/images`
