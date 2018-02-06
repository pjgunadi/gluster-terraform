#!/bin/bash

apt install -y glusterfs-server thin-provisioning-tools glusterfs-client
modprobe dm_thin_pool
echo dm_thin_pool | tee -a /etc/modules
