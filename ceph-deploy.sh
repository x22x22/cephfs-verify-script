#!/bin/bash

mkdir -p "${HOME}"/ceph-cluster
cd "${HOME}"/ceph-cluster || exit
ceph-deploy new storage-ha-1 storage-ha-2 storage-ha-3

cat >>ceph.conf <<EOF
# 'public network':
# 整个集群所存在的网段
# 这里需要根据实际情况修改
public network = 192.168.60.0/24
osd pool default size = 3
osd pool default min size = 2
osd pool default pg num = 100
osd pool default pgp num = 100
# 'mon allow pool delete': 
# 此设置允许删除pool的操作, poc环境为方便操作加上此选项, 生产环境建议注释
mon allow pool delete = true

[osd]
osd_max_backfills = 1
osd_recovery_max_active = 1
osd_recovery_op_priority = 1
EOF

# 在各个节点上安装ceph, 并指定了外网的ceph yum源, 如果无法访问外网请自行搭建并修改
ceph-deploy install storage-ha-1 storage-ha-2 storage-ha-3 --repo-url http://mirrors.ustc.edu.cn/ceph/rpm-mimic/el7 --gpg-url 'http://mirrors.ustc.edu.cn/ceph/keys/release.asc'
# 初始化mon服务和key信息
ceph-deploy mon create-initial
ceph-deploy mon add storage-ha-2
ceph-deploy mon add storage-ha-3
ceph-deploy admin storage-ha-1 storage-ha-2 storage-ha-3
ceph-deploy mgr create storage-ha-1 storage-ha-2 storage-ha-3

# 添加存储服务节点上的裸盘到存储池中
ceph-deploy osd create --data /dev/sdb storage-ha-1
ceph-deploy osd create --data /dev/sdb storage-ha-2
ceph-deploy osd create --data /dev/sdb storage-ha-3

ceph-deploy mds create storage-ha-1 storage-ha-2 storage-ha-3

ssh storage@storage-ha-1 << EOF
# 创建两个pool, 服务于cephfs, cephfs至少需要两个pool, 分别做metadata和data
sudo ceph osd pool create cephfs_data 100
# 使用raid 5方式存储数据即erasure类型, 当单个文件平均大小大于8k时erasure比replicated有优势.
# sudo ceph osd pool create cephfs_data 100 100 erasure
# sudo ceph osd pool set cephfs_data allow_ec_overwrites true
# sudo metadata pool必须使用replicated类型.
sudo ceph osd pool create cephfs_metadata 100
# 如果使用了erasure类型, 此步骤跳过
sudo ceph osd pool set cephfs_data size 3

sudo ceph osd pool set cephfs_metadata size 3
sudo ceph fs new cephfs cephfs_metadata cephfs_data

# 查看集群各项信息
sudo ceph quorum_status --format json-pretty
sudo ceph fs ls
sudo ceph mds stat
sudo ceph health
sudo ceph -s
EOF
