#!/bin/bash

# Quickly purge cluster if failed bootstrap

ansible ceph -i inventory.ini -b -m shell -a \
  'for f in $(ls /var/lib/ceph/ 2>/dev/null | grep -E "^[0-9a-f]{8}-"); do cephadm rm-cluster --fsid "$f" --force --zap-osds; done; rm -rf /etc/ceph/*'
