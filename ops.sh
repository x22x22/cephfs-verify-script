#!/bin/bash

# 简单测试写性能
time dd if=/dev/zero of=/mnt/mycephfs/test.dbf bs=8k count=3000 oflag=direct

# 删除cephfs前需要的操作
# 每个mds节点上都要执行
systemctl stop ceph-mds.target
ceph fs rm cephfs --yes-i-really-mean-it
ceph osd pool rm cephfs_data cephfs_data --yes-i-really-really-mean-it
ceph osd pool rm cephfs_metadata cephfs_metadata --yes-i-really-really-mean-it
# 每个mds节点上都要执行
systemctl start ceph-mds.target
systemctl restart ceph-mon.target

# 将新配置文件并上传到所以节点
ceph-deploy --overwrite-conf config push storage-ha-1 storage-ha-2 storage-ha-3