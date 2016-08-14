.PHONY: etcd

ETCD_ARM_IMAGE := gcr.io/google_containers/etcd-arm:2.2.1

etcd: bin/etcd bin/etcdctl

bin/etcd:
	@mkdir -p bin
	docker create --name etcd-arm $(ETCD_ARM_IMAGE)
	docker cp etcd-arm:/usr/local/bin/etcd bin/etcd
	docker rm etcd-arm

bin/etcdctl:
	@mkdir -p bin
	docker create --name etcd-arm gcr.io/google_containers/etcd-arm:2.2.1
	docker cp etcd-arm:/usr/local/bin/etcdctl bin/etcdctl
	docker rm etcd-arm

copy-etcd-%:
	scp -i ${PWD}/.id_rsa_$*.key bin/{etcd,etcdctl} pirate@$*.local:~/
