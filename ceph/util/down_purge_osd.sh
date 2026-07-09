#!/bin/bash
OSD_ID=$1

if [ -z "$OSD_ID" ]; then
    echo "Usage: $0 <id>"
    exit 1
fi

# Check if OSD is in the cluster
if ceph osd dump | grep -q "^osd.${OSD_ID} .* in "; then
    echo "Abort: osd.${OSD_ID} is still IN. Mark it OUT first."
    exit 1
fi

# Proceed if OUT
echo "Purging osd.${OSD_ID}..."
ceph osd down "osd.${OSD_ID}"
ceph osd purge "${OSD_ID}" --yes-i-really-mean-it

