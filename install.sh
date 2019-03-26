#!/bin/sh

sudo yum install -y yum-utils \
  device-mapper-persistent-data \
  lvm2
  
yum-config-manager \
  --add-repo \
  http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
  
yum install docker-ce docker-ce-cli containerd.io -y

cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF

# 关闭swap
sudo swapoff -a
# 关闭selinux
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# 安装 kubelet kubeadm  kubectl
yum install -y kubelet kubeadm kubectl

# 部署 docker
sudo systemctl daemon-reload
sudo systemctl enable kubelet && systemctl start kubelet

echo "{\
  \"registry-mirrors\": [\"https://registry.docker-cn.com\"]\
}" > /etc/docker/daemon.json

sudo systemctl enable docker && systemctl start docker

sudo kubeadm config images list |sed -e 's/^/docker pull /g' -e 's#k8s.gcr.io#docker.io/mirrorgooglecontainers#g' | sh -x
sudo docker images |grep mirrorgooglecontainers |awk '{print "docker tag",$1":"$2,$1":"$2}' |sed -e 's/docker\.io\/mirrorgooglecontainers/k8s.gcr.io/2' |sh -x
sudo docker images |grep mirrorgooglecontainers |awk '{print "docker rmi """$1""":"""$2}' |sh -x
sudo docker pull coredns/coredns:1.2.6
sudo docker tag coredns/coredns:1.2.6 k8s.gcr.io/coredns:1.2.6
sudo docker rmi coredns/coredns:1.2.6

sudo sysctl net.bridge.bridge-nf-call-iptables=1

# 启动kubelet
sudo systemctl start kubelet
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "export KUBECONFIG=$HOME/.kube/config" >> $HOME/.bash_profile
source $HOME/.bash_profile

## master
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/a70459be0084506e4ec919aa1c114638878db11b/Documentation/kube-flannel.yml

# kubectl taint nodes --all node-role.kubernetes.io/master-
