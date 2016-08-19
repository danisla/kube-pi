#!/bin/bash

set -e
set -x

[[ -z $1 ]] && echo "USAGE: $0 <internal ip>" && exit 1

export ETCD_NAME=$(hostname -s)
export INTERNAL_IP=$1

sudo mkdir -p /etc/etcd
sudo cp *.pem /etc/etcd/

sudo mv etcd* /usr/bin/
sudo chmod +x /usr/bin/etcd*

sudo mkdir -p /var/lib/etcd

cat > etcd.service <<"EOF"
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
ExecStart=/usr/bin/etcd --name ETCD_NAME \
  --cert-file=/etc/etcd/kubernetes.pem \
  --key-file=/etc/etcd/kubernetes-key.pem \
  --peer-cert-file=/etc/etcd/kubernetes.pem \
  --peer-key-file=/etc/etcd/kubernetes-key.pem \
  --trusted-ca-file=/etc/etcd/ca.pem \
  --peer-trusted-ca-file=/etc/etcd/ca.pem \
  --initial-advertise-peer-urls https://INTERNAL_IP:2380 \
  --listen-peer-urls https://INTERNAL_IP:2380 \
  --listen-client-urls https://INTERNAL_IP:2379,http://127.0.0.1:2379 \
  --advertise-client-urls https://INTERNAL_IP:2379 \
  --initial-cluster-token etcd-cluster-0 \
  --initial-cluster ETCD_NAME=https://INTERNAL_IP:2380 \
  --initial-cluster-state new \
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sed -i s/INTERNAL_IP/$INTERNAL_IP/g etcd.service
sed -i s/ETCD_NAME/$ETCD_NAME/g etcd.service

sudo mv etcd.service /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl enable etcd
sudo systemctl start etcd

sudo systemctl status etcd --no-pager

sleep 10 && etcdctl --ca-file=/etc/etcd/ca.pem cluster-health

echo "INFO: etcd setup complete."
