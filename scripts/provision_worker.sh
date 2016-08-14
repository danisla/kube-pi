#!/bin/bash

set -e

[[ -z $1 || -z $2 ]] && echo "USAGE: $0 <internal ip> <master ip>" && exit 1

export INTERNAL_IP=$1
export MASTER_IP=$2


### Certs ###

sudo mkdir -p /var/lib/kubernetes

sudo cp *.pem /var/lib/kubernetes/


### Docker ###

sudo sh -c 'echo "[Unit]
Description=Docker Application Container Engine
Documentation=http://docs.docker.io

[Service]
ExecStart=/usr/bin/docker daemon \
  --iptables=false \
  --ip-masq=false \
  --host=unix:///var/run/docker.sock \
  --log-level=error \
  --storage-driver=overlay
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/docker.service'

sudo systemctl daemon-reload
sudo systemctl enable docker
sudo systemctl start docker

sudo docker version


### Kubelet ###

sudo mkdir -p /opt/cni
sudo cp cni/* /opt/cni/
sudo chmod +x /opt/cni/*

sudo cp hyperkube /usr/bin/
sudo chmod +x /usr/bin/hyperkube

sudo mkdir -p /var/lib/kubelet/

## kubeconfig ##

sudo sh -c 'echo "apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority: /var/lib/kubernetes/ca.pem
    server: https://10.240.0.20:6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: kubelet
  name: kubelet
current-context: kubelet
users:
- name: kubelet
  user:
    token: chAng3m3" > /var/lib/kubelet/kubeconfig'

## kubelet service ##

sudo sh -c 'echo "[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=docker.service
Requires=docker.service

[Service]
ExecStart=/usr/bin/hyperkube kubelet \
  --allow-privileged=true \
  --api-servers=https://'${MASTER_IP}':6443 \
  --cloud-provider= \
  --cluster-dns=10.32.0.10 \
  --cluster-domain=cluster.local \
  --configure-cbr0=true \
  --container-runtime=docker \
  --docker=unix:///var/run/docker.sock \
  --network-plugin=kubenet \
  --kubeconfig=/var/lib/kubelet/kubeconfig \
  --reconcile-cidr=true \
  --serialize-image-pulls=false \
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \
  --v=2

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/kubelet.service'

sudo systemctl daemon-reload
sudo systemctl enable kubelet
sudo systemctl start kubelet

sleep 5 && sudo systemctl status kubelet --no-pager

## kube proxy ##

sudo sh -c 'echo "[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/usr/bin/hyperkube proxy \
  --master=https://'${MASTER_IP}':6443 \
  --kubeconfig=/var/lib/kubelet/kubeconfig \
  --proxy-mode=iptables \
  --v=2

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/kube-proxy.service'

sudo systemctl daemon-reload
sudo systemctl enable kube-proxy
sudo systemctl start kube-proxy

sleep 5 && sudo systemctl status kube-proxy --no-pager
