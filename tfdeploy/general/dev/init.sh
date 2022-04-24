#!/bin/bash
set -euxo pipefail
echo "####### Installing Prerequisite #######"
apt update
apt -y install vim git curl apt-transport-https wget gnupg2 software-properties-common ca-certificates mysql-client
echo "####### Add Docker Key #######"
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
echo "####### Install Docker #######"
apt update
apt install -y containerd.io docker-ce docker-ce-cli
systemctl start docker && systemctl enable docker
echo "####### Configure Docker #######"
mkdir -p /etc/systemd/system/docker.service.d
cat > /etc/docker/daemon.json <<EOF
{
  "data-root": "/data/docker/",
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "20"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ],
  "dns": ["8.8.8.8"]
}
EOF
cat <<EOF > /etc/sysctl.d/docker.conf
net.ipv4.conf.all.forwarding = 1
EOF
sysctl --system
systemctl daemon-reload
systemctl restart docker
echo "####### Installation End #######"