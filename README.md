# Kubernetes the hard way on Raspberry Pi

Inspired by: https://github.com/kelseyhightower/kubernetes-the-hard-way

Using [`HypriotOS`](http://blog.hypriot.com/downloads/) for Docker on ARM.

Components:

- SD flashing using [`hypriot/flash`](https://github.com/hypriot/flash)
- ARM build of [`hyperkube`](https://github.com/kubernetes/kubernetes/tree/master/cluster/images/hyperkube), gcr.io image: [`gcr.io/google_containers/hyperkube-arm`](./hyperkube.mk)
- ARM build of etcd from gcr.io image: [`gcr.io/google_containers/etcd-arm`](./etcd.mk)
- ARM build of cni plugins from the [cni repo](https://github.com/containernetworking/cni), built using [local docker](./cni.mk).
- Certs generated per host with [`cfssl`](./cfssl.mk).
- Provisioning from guide translated to shell [`scripts`](./scripts), invoked by Makefile rule.

## Default setup:

- 1 master node: `kpi-master.local`
- 2 worker nodes: `kpi-worker0.local`, `kpi-worker1.local`
- Cluster CIDR: `10.200.0.0/16`
- Service Cluster CIDR: `10.32.0.0/16`
- DNS (not yet)

## SD Card Setup

Run this to flash all of the SD cards for each node (prompted for each one):

```
make
```

> Note, until the hypriot image adds `cgroup_enable=cpuset` to /boot/cmdline.txt, you should do this manually before booting or the kubelet service won't start. see also: https://github.com/kubernetes/kubernetes/issues/26038

Insert SD card to each PI and boot them, make sure networking is working properly before continuing.

Each host should be resolvable using its `.local` mDNS name:

```
ping kpi-master.local
ping kpi-worker0.local
ping kpi-worker1.local
```

## Provisioning K8S

Run this to generate and copy ssh keys, copy all files and run the scripts:

```
make provision
```

## Networking

POD networking is done by adding static routes for the cluster network on each node to all of the other nodes.

Here are the example route commands for a cluster with 3 worker nodes. The `192.168.1.0` subnet is for my local network on the Pi's `eth0` interface and the `10.200.x.x` is the K8S cluster network:

First, fetch the `podCIDR` definitions for each node:

```
$ hyperkube kubectl get nodes -o json | jq '.items[].spec'
{
  "podCIDR": "10.200.0.0/24",
  "externalID": "kpi-worker0"
}
{
  "podCIDR": "10.200.1.0/24",
  "externalID": "kpi-worker1"
}
{
  "podCIDR": "10.200.2.0/24",
  "externalID": "kpi-worker2"
}
```

The `route add` commands for `kpi-worker0`:

```
sudo route add -net 10.200.1.0/24 gw 192.168.1.20 dev eth0
sudo route add -net 10.200.2.0/24 gw 192.168.1.123 dev eth0
```

The `route add` commands for `kpi-worker1`:

```
sudo route add -net 10.200.0.0/24 gw 192.168.1.124 dev eth0
sudo route add -net 10.200.2.0/24 gw 192.168.1.123 dev eth0
```

The `route add` commands for `kpi-worker2`:

```
sudo route add -net 10.200.0.0/24 gw 192.168.1.124 dev eth0
sudo route add -net 10.200.1.0/24 gw 192.168.1.20 dev eth0
```

This is all automated when you run `make add-routes` after provisioning all of the nodes.

> NOTE: Trying to ping the `10.200.0.0/16` addresses from other workers may give strange results if the `cbr0` interface hasn't been created yet on the destination host, this is created automatically by the kubelet the first time a container is run.

## TODO

- [ ] DNS setup
- [ ] external access
