# Kubernetes on CentOS 7/8 with Firewalld

## Minimum System Requirements
- 1x Master VM with minimum 2vCPU and 2GB of RAM
- 1-2x Worker VMs with minimum 2vCPU and 2GB of RAM (You can change this config according to the workloads you run)

CentOS 7/8 should be installed on all the machines. I used VirtualBox images of CentOS 8.3.2011 from https://www.linuxvmimages.com/images/virtualbox/ ("Regular Download" was really faster than "Faster Download").
Make sure that all VMs are connected to the same network. I used "Bridged Adapter" to allow all VMs have Internet connection.

Set the hostname on each VM (optional):
```
# On Master
sudo hostnamectl set-hostname k8s-master.linuxvmimages.local
sudo reboot

# On Worker 1
sudo hostnamectl set-hostname k8s-worker1.linuxvmimages.local
sudo reboot
```

## Installing Prerequisites
To get started we need to configure all of the VMs with a container runtime (docker in our case) and Kubernetes packages. Script installing **Kubernetes 1.16.8**. If you need another Kubernetes version then go to `k8s-centos.sh` and edit line with `yum install -y kubelet-1.16.8 ...` to required package version. For example if you need the latest version then edit it as `yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes`

Then run the following script in all of your nodes using the following command:
```
curl -s https://raw.githubusercontent.com/eyuriev/k8s-cluster/main/k8s-centos.sh | sh -s
```

## Open Ports on Firewall
With firewalld enabled, you have to open the following ports in order for Kubernetes to work properly. Please note that if you are running this in Cloud, you need to enable these ports on your particular VPC subnet as well.

[Check required ports](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#check-required-ports)

On Master open the following ports and restart the service:
```
sudo firewall-cmd --permanent --add-port=6443/tcp
sudo firewall-cmd --permanent --add-port=2379-2380/tcp
sudo firewall-cmd --permanent --add-port=10250/tcp
sudo firewall-cmd --permanent --add-port=10251/tcp
sudo firewall-cmd --permanent --add-port=10252/tcp
sudo firewall-cmd --permanent --add-port=10255/tcp
sudo firewall-cmd --permanent --add-port=8472/udp
sudo firewall-cmd --add-masquerade --permanent
# only if you want NodePorts exposed on control plane IP as well
sudo firewall-cmd --permanent --add-port=30000-32767/tcp
sudo systemctl restart firewalld
```

On Worker Nodes open the following ports and restart the service:
```
sudo firewall-cmd --permanent --add-port=10250/tcp
sudo firewall-cmd --permanent --add-port=10255/tcp
sudo firewall-cmd --permanent --add-port=8472/udp
sudo firewall-cmd --permanent --add-port=30000-32767/tcp
sudo firewall-cmd --add-masquerade --permanent
sudo systemctl restart firewalld
```

## Init the master
Passing `--pod-network-cidr=10.244.0.0/16` because [Flannel](https://github.com/flannel-io/flannel) CNI is used.
```
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
```
To start using your cluster, you need to run the following as a regular user:
```
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

## Install [Flannel](https://github.com/flannel-io/flannel)
You should now deploy a pod network to the cluster.
Run `kubectl apply -f [podnetwork].yaml` with one of the options listed at: https://kubernetes.io/docs/concepts/cluster-administration/addons/

For Kubernetes v1.17+
```
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```
**NOTE:** If kubeadm is used, then pass `--pod-network-cidr=10.244.0.0/16` to kubeadm init to ensure that the podCIDR is set.

With this completed, Your master should be in a ready state in a couple of mins. You can check status by running.
```
kubectl get nodes
```

## Join the Workers
Now since Master is configured, you can go ahead and join any number of worker nodes you need by running the join command you copy pasted and saved after you ran the `kubeadm init` command. If you have lost it, don’t worry we can always generate a new one by running on the Master the following (as root user):
```
kubeadm token create --print-join-command
```
Run the join command on the terminals of the worker nodes as root.

## Running an Application in the Cluster
Still within the master node, execute the following command to create a deployment named _nginx_:
```
kubectl create deployment nginx --image=nginx
```
Next, run the following command to create a service named _nginx_ that will expose the app:
```
kubectl expose deploy nginx --port 80 --target-port 80
```
Run the following command from the Master to check services:
```
kubectl get services
```
This will output text similar to the following:
```
NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   10.96.0.1       <none>        443/TCP   124m
nginx        ClusterIP   10.102.57.193   <none>        80/TCP    107m
```
Then try to connect via _curl_ to _nginx_ service. If you see Welcome message from _nginx_ then service is configured, up and running properly.
```
curl 10.102.57.193
```
