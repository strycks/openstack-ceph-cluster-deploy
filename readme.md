# IMPORTANT NOTE: THIS BRANCH ONLY CONTAINS THE DEPLOYMENT FOR CEPH CLUSTER, FOR OPENSTACK-CEPH PLEASE VISIT MASTER BRANCH.

# Automated OpenStack-Ceph Provisioning

Automated provisioning of OpenStack and Ceph on libvirt VMs: Terraform
provisions the VMs, Ansible deploys Ceph (cephadm), OpenStack (kolla-ansible), and integrates Ceph as the storage backend.

## Topology

7 VMs on Ubuntu 24.04 (noble), user `ubuntu`:

| Host | Role | Notes |
|---|---|---|
| `openstack-node1` | OpenStack (kolla-ansible) | 8 vCPU / 16 GiB |
| `ceph-node1` | ceph-admin (`_admin`, mon, mgr, mds, osd) | bootstrap host |
| `ceph-node2`–`ceph-node3` | mon, mgr, mds, osd | |
| `ceph-node4`–`ceph-node6` | rgw, osd | |

Interfaces on the OpenStack node:

- `ens3` = mgmt (DHCP), `ens4` = ceph public, `ens5` = os-internal,
  `ens6` = os-external, `ens7` = os-tenant

Interfaces on the Ceph nodes:

- `ens3` = mgmt (DHCP), `ens4` = ceph public, `ens5` = os-internal,
  `ens6` = ceph cluster

### Networks (libvirt)

| Network | CIDR | Mode | Purpose |
|---|---|---|---|
| mgmt | `10.10.250.0/24` | DHCP + NAT | SSH/Ansible |
| ceph-public | `10.10.2.0/24` | none | ceph nodes `.21`–`.26` |
| os-internal | `10.10.3.0/24` | none | internal API, VIP `10.10.3.250` |
| os-external | `10.10.4.0/24` | none | external API, VIP `10.10.4.250` |
| os-tenant | `10.10.5.0/24` | NAT, no DHCP | neutron SDN, floating IPs |
| ceph-cluster | `10.10.6.0/24` | none | ceph cluster network |

VIP host octet is always `250` (also RGW ingress `10.10.2.250:80`).

## Resource Consumption

The 7 VMs are expected to consume at most 32 vCPU / 40 GiB RAM plus ~670 GiB of disks (both HDD and SSD). 

Notes:

- The kolla-ansible bootstrap/deploy phase is CPU and I/O-heavy; expect a long
  first `terraform apply` too (7 Ubuntu cloud images + cloud-init).
- OSD disks are created with `rotation_rate` hints, so the ssd pool must be on
  real SSDs for the device-class rules to be useful.
- Scaling down isn't trivial: the EC 4+2 pools (`ssd-ec42`/`hdd-ec42`) need at
  least 6 hosts for their CRUSH rules.

## Prerequisites

- libvirt (`qemu:///system`), with SSD pool (`/var/lib/libvirt/images`) and HDD
  pool (`/mnt/hdd-linux/vms-storage`, see `terraform/variables.tf`)
- `~/.ssh/id_ed25519` (public key is injected into the VMs by cloud-init)
- Terraform >= 1.5, libvirt provider pinned `< 0.9.0` (classic API)
- Ansible + the `ceph.automation` collection (`>=1.2.0`, see `requirements.yml`)

Note: disable CoW on the image pool before provisioning if using btrfs
(`sudo chattr +C /var/lib/libvirt/images`).

## Deploy

```sh
cd terraform
terraform apply          # provisions VMs, regenerates ansible/inventory.ini
cd ../ansible
ansible-galaxy collection install -r requirements.yml   # once
ansible-playbook ceph/site.yml                          # deploy Ceph
ansible-playbook openstack/site.yml                     # deploy OpenStack 
ansible-playbook openstack/init-runonce.yml             # seed demo resources, only run ONCE
```
