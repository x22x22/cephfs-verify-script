#!/bin/bash

# 禁用ipv6
cat >>/etc/sysctl.conf <<EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF

sysctl -p
sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1

# 简单代替dns服务器写入当前环境中的主机名和ip的对应关系
cat >>/etc/hosts <<EOF

192.168.60.110 storage-deploy-1
192.168.60.111 storage-ha-1
192.168.60.112 storage-ha-2
192.168.60.113 storage-ha-3
EOF

systemctl stop firewalld
systemctl disable firewalld
setenforce 0
sed -i 's/SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config

# 添加ceph的yum源, 如果无法访问外面请自行搭建并修改
cat >/etc/yum.repos.d/ceph.repo <<'EOF'
[Ceph]
name=Ceph packages for $basearch
baseurl=http://mirror.tuna.tsinghua.edu.cn/ceph/rpm-mimic/el7/$basearch
enabled=1
gpgcheck=1
type=rpm-md
gpgkey=https://mirror.tuna.tsinghua.edu.cn/ceph/keys/release.asc
priority=1

[Ceph-noarch]
name=Ceph noarch packages
baseurl=http://mirror.tuna.tsinghua.edu.cn/ceph/rpm-mimic/el7/noarch
enabled=1
gpgcheck=1
type=rpm-md
gpgkey=https://mirror.tuna.tsinghua.edu.cn/ceph/keys/release.asc
priority=1

[ceph-source]
name=Ceph source packages
baseurl=http://mirror.tuna.tsinghua.edu.cn/ceph/rpm-mimic/el7/SRPMS
enabled=1
gpgcheck=1
type=rpm-md
gpgkey=https://mirror.tuna.tsinghua.edu.cn/ceph/keys/release.asc
priority=1

EOF

mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup

# 修改CentOS的yum基础源, 如果无法访问外面请自行搭建并修改
cat >/etc/yum.repos.d/CentOS-Base.repo <<'EOF'
# CentOS-Base.repo
#
# The mirror system uses the connecting IP address of the client and the
# update status of each mirror to pick mirrors that are updated to and
# geographically close to the client.  You should use this for CentOS updates
# unless you are manually picking other mirrors.
#
# If the mirrorlist= does not work for you, as a fall back you can try the
# remarked out baseurl= line instead.
#
#

[base]
name=CentOS-$releasever - Base
baseurl=https://mirrors.tuna.tsinghua.edu.cn/centos/$releasever/os/$basearch/
#mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=os
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

#released updates
[updates]
name=CentOS-$releasever - Updates
baseurl=https://mirrors.tuna.tsinghua.edu.cn/centos/$releasever/updates/$basearch/
#mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=updates
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

#additional packages that may be useful
[extras]
name=CentOS-$releasever - Extras
baseurl=https://mirrors.tuna.tsinghua.edu.cn/centos/$releasever/extras/$basearch/
#mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=extras
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

#additional packages that extend functionality of existing packages
[centosplus]
name=CentOS-$releasever - Plus
baseurl=https://mirrors.tuna.tsinghua.edu.cn/centos/$releasever/centosplus/$basearch/
#mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=centosplus
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
EOF

yum makecache fast
# 安装CentOS的yum epel源
yum install -y epel-release

# 修改CentOS的yum epel源, 如果无法访问外面请自行搭建并修改
cat >/etc/yum.repos.d/epel.repo <<'EOF'
[epel]
name=Extra Packages for Enterprise Linux 7 - $basearch
baseurl=https://mirrors.tuna.tsinghua.edu.cn/epel/7/$basearch
#mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=epel-7&arch=$basearch
failovermethod=priority
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7

[epel-debuginfo]
name=Extra Packages for Enterprise Linux 7 - $basearch - Debug
baseurl=https://mirrors.tuna.tsinghua.edu.cn/epel/7/$basearch/debug
#mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=epel-debug-7&arch=$basearch
failovermethod=priority
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7
gpgcheck=1

[epel-source]
name=Extra Packages for Enterprise Linux 7 - $basearch - Source
baseurl=https://mirrors.tuna.tsinghua.edu.cn/epel/7/SRPMS
#mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=epel-source-7&arch=$basearch
failovermethod=priority
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7
gpgcheck=1
EOF

yum makecache
yum install yum-plugin-priorities chrony sshpass ceph-deploy ceph -y
mv /etc/chrony.conf /etc/chrony.conf.bk

# 添加时间同步服务器, 如果无法访问外面请自行搭建并修改
cat > /etc/chrony.conf << EOF
server 0.cn.pool.ntp.org iburst
server 1.cn.pool.ntp.org iburst
server 2.cn.pool.ntp.org iburst
server 3.cn.pool.ntp.org iburst
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
logdir /var/log/chrony
EOF

systemctl enable chronyd
systemctl restart chronyd
chronyc sources -v

rm -f "${HOME}"/.ssh/ceph_id_rsa
ssh-keygen -t rsa -b 4096 -f "${HOME}"/.ssh/ceph_id_rsa -N ''
cat >"${HOME}"/.ssh/config <<EOF
Host storage-ha-1
   Hostname storage-ha-1
   User storage
   IdentityFile ${HOME}/.ssh/ceph_id_rsa
   IdentitiesOnly yes
   StrictHostKeyChecking no
Host storage-ha-2
   Hostname storage-ha-2
   User storage
   IdentityFile ${HOME}/.ssh/ceph_id_rsa
   IdentitiesOnly yes
   StrictHostKeyChecking no
Host storage-ha-3
   Hostname storage-ha-3
   User storage
   IdentityFile ${HOME}/.ssh/ceph_id_rsa
   IdentitiesOnly yes
   StrictHostKeyChecking no
EOF
chmod 0400 "${HOME}"/.ssh/config
sshpass -p "fullstackmemo***" ssh-copy-id -i ~/.ssh/ceph_id_rsa storage@storage-ha-1
sshpass -p "fullstackmemo***" ssh-copy-id -i ~/.ssh/ceph_id_rsa storage@storage-ha-2
sshpass -p "fullstackmemo***" ssh-copy-id -i ~/.ssh/ceph_id_rsa storage@storage-ha-3

mkdir -p "${HOME}"/ceph-cluster
cd "${HOME}"/ceph-cluster || exit