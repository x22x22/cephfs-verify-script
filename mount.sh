#!/bin/bash

# cephfs方式挂载
yum install ceph -y
mkdir -p /etc/ceph
mkdir -p /mnt/mycephfs
# 以下写入的secret请根据'获取用户授权信息'章节中获取到的'key'进行修改
cat > /etc/ceph/admin_secret.key << EOF
AQAm4L5b60alLhAARxAgr9jQDLopr9fbXfm87w==
EOF

# 以下写入的secret请根据'获取用户授权信息'章节中获取到的'key'进行修改
cat > /etc/ceph/test_cephfs_1_secret.key << EOF
AQA0Cr9b9afRDBAACJ0M8HxsP41XmLhbSxWkqA==
EOF

mount.ceph 192.168.60.111:6789,192.168.60.112:6789,192.168.60.113:6789:/ /mnt/mycephfs -o name=admin,secretfile=/etc/ceph/admin_secret.key

# 使用只读的用户挂载
mkdir -p /mnt/mycephfs/test_1
mkdir -p /mnt/test_cephfs_1
mount.ceph 192.168.60.111:6789,192.168.60.112:6789,192.168.60.113:6789:/ /mnt/test_cephfs_1 -o name=fs-test-1,secretfile=/etc/ceph/test_cephfs_1_secret.key

# 开机自动挂载
cat >> /etc/fstab << EOF
192.168.60.111:6789,192.168.60.112:6789,192.168.60.113:6789:/     /mnt/mycephfs    ceph    name=admin,secretfile=/etc/ceph/secret.key,noatime,_netdev    0       2
EOF

# ceph-fuse方式挂载
yum install ceph-fuse -y
mkdir -p /etc/ceph
mkdir -p /mnt/mycephfs

scp storage@storage-ha-1:/etc/ceph/ceph.conf /etc/ceph/ceph.conf

# 以下写入的secret请根据'获取用户授权信息'章节中获取到的'key'进行修改
cat > /etc/ceph/ceph.keyring << EOF
[client.admin]
        key = AQAm4L5b60alLhAARxAgr9jQDLopr9fbXfm87w==
        caps mds = "allow *"
        caps mgr = "allow *"
        caps mon = "allow *"
        caps osd = "allow *"
[client.fs-test-1]
        key = AQA0Cr9b9afRDBAACJ0M8HxsP41XmLhbSxWkqA==
        caps mds = "allow r, allow rw path=/test-1"
        caps mon = "allow r"
        caps osd = "allow rw tag cephfs data=cephfs"
EOF
ceph-fuse -m 192.168.60.111:6789,192.168.60.112:6789,192.168.60.113:6789 /mnt/mycephfs
# 开机自动挂载
cat >> /etc/fstab << EOF
none    /mnt/ceph  fuse.ceph ceph.id=admin,ceph.conf=/etc/ceph/ceph.conf,_netdev,defaults  0 0
EOF

# 使用只读的用户挂载
mkdir -p /mnt/mycephfs/test_1
mkdir -p /mnt/test_cephfs_1
mount.ceph 192.168.60.111:6789,192.168.60.112:6789,192.168.60.113:6789:/ /mnt/test_cephfs_1 -o name=fs-test-1