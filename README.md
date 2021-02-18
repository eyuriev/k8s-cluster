# Installing Prerequisites
To get started we need to configure all of the VMs with a container runtime (docker in our case) and kubernetes packages. To do this, please go ahead and run the following script in all of your nodes using the following command.

sudo su -
curl -s https://gist.githubusercontent.com/nilesh93/609c8152fc96b38340de20d1e0ed7c5a/raw/abf4f28e9e2157a38bf3cf0caa8730db6c344e1f/kuberentes-centos-7.sh | sh -s
