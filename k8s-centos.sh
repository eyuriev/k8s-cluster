#!/bin/bash

sudo yum update -y
sudo yum install -y net-tools bind-utils wget telnet yum-utils device-mapper-persistent-data lvm2

## Add the Docker repository
sudo yum-config-manager --add-repo \
  https://download.docker.com/linux/centos/docker-ce.repo -y

# Install Docker CE
sudo yum update -y && sudo yum install -y containerd.io docker-ce docker-ce-cli

## Create /etc/docker
sudo mkdir /etc/docker

# Set up the Docker daemon
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ]
}
EOF

# Create /etc/systemd/system/docker.service.d
sudo mkdir -p /etc/systemd/system/docker.service.d

# Restart Docker
sudo systemctl daemon-reload
sudo systemctl enable docker
sudo systemctl restart docker

# Disable swap
sudo swapoff -a
sudo sed -i 's/^\(.*swap.*\)$/#\1/' /etc/fstab 

# Installing kubeadm
# https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
# load netfilter probe specifically
sudo modprobe br_netfilter
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

# Set SELinux in permissive mode (effectively disabling it)
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# Enable IP Forwarding
# echo '1' > /proc/sys/net/bridge/bridge-nf-call-iptables
echo '1' | sudo tee /proc/sys/net/bridge/bridge-nf-call-iptables
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system

# Install Kuberentes packages
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF

# In our case install versions like in OCI PROD 1.16.8
# yum -y install kubectl kubelet kubeadm
sudo yum install -y kubelet-1.16.8 kubeadm-1.16.8 kubectl-1.16.8 --disableexcludes=kubernetes

# Restart and enable Kubelet
sudo systemctl daemon-reload
sudo systemctl restart kubelet && sudo systemctl enable kubelet
