Management Network: `10.10.250.0/24` dhcp  
Ceph Public Network: `10.10.2.10/24 (Openstack) 10.10.2.{id + 20}/24 (Ceph)`  
Ceph Cluster Network: `10.10.6.{id + 20}/24 (Ceph)`  

Remember to turn off CoW on image pools:
```sudo chattr +C /var/lib/libvirt/images```  
Also chown and chmod qemu on mountpoint.

For convenient, edit ssh config to ssh with alias.
