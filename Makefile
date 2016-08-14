
FLASH=/usr/local/bin/flash
HYPRIOT_IMAGE_URL := https://downloads.hypriot.com/hypriotos-rpi-v0.8.0.img.zip
HYPRIOT_IMAGE := $(notdir $(HYPRIOT_IMAGE_URL))
USER_HOME=/home/pirate
MASTER_NODES := kpi-master.local
WORKER_NODES := kpi-worker0.local kpi-worker1.local kpi-worker2.local

HOST_PREFIXES := kpi-master kpi-worker
HOSTS := $(MASTER_NODES) $(WORKER_NODES)

CLUSTER_CIDR := 10.200.0.1
SERVICE_CLUSTER_IP := 10.32.0.1

all: $(addprefix flash-,$(subst .local,,$(HOSTS)))
clean: clean-certs
	-rm -f certs/*
	-rm -f .*.key
	- rm -f .*.key.pub

provision: provision-masters provision-workers

provision-masters: $(addprefix provision-master-,$(subst .local,,$(MASTER_NODES)))
provision-master-%: bin-files certs install-ssh-key-% copy-files-%
	ssh -i ${PWD}/.id_rsa_$*.key -t pirate@$*.local 'bash -c "bash ~/provision_etcd.sh $(shell make port-ips-$*)"'
	ssh -i ${PWD}/.id_rsa_$*.key -t pirate@$*.local 'bash -c "bash ~/provision_master.sh $(shell make port-ips-$*)"'

provision-workers: $(addprefix provision-worker-,$(subst .local,,$(WORKER_NODES)))
provision-worker-%: port-vars bin-files certs install-ssh-key-% copy-files-%
	ssh -i ${PWD}/.id_rsa_$*.key -t pirate@$*.local 'bash -c "bash ~/provision_worker.sh $(shell make port-ips-$*) $(shell make port-ips-kpi-master)"'

clean-provision-%:
	ssh -i ${PWD}/.id_rsa_$*.key -t pirate@$*.local 'bash -c "rm -Rf ~/*.pem ~/hyperkube ~/etcd* ~/cni ~/provison_*.sh"'

$(FLASH):
	wget -O $@ https://raw.githubusercontent.com/hypriot/flash/master/$(shell uname -s)/flash
	chmod +x $@

$(HYPRIOT_IMAGE):
	curl -LO $(HYPRIOT_IMAGE_URL)

flash-%: $(HYPRIOT_IMAGE) $(FLASH)
	$(warning flashing SD for host: $*)
	flash --hostname $* $<

uptime: $(addprefix uptime-, $(subst .local,,$(HOSTS)))

uptime-%:
	@ssh -i ${PWD}/.id_rsa_$*.key -t pirate@$*.local 'hostname && uptime' 2>/dev/null

get-host-ips-json:
	@./util/bonjour_to_ip_json.sh $(HOSTS) | jq .

install-ssh-keys: $(addprefix install-ssh-key-, $(subst .local,,$(HOSTS)))

install-ssh-key-%: .id_rsa_%.key
	$(warning NOTE: default password is: hypriot)
	@ssh -T pirate@$*.local 'bash -c "mkdir -p ${USER_HOME}/.ssh && chmod 0700 ${USER_HOME}/.ssh && echo \"$(shell cat $<.pub)\" >> ${USER_HOME}/.ssh/authorized_keys && chmod 0600 ${USER_HOME}/.ssh/authorized_keys"'

.PRECIOUS: .id_rsa_%.key
.id_rsa_%.key:
	ssh-keygen -t rsa -b 4096 -N '' -f $@

gen-ssh-keys: $(addsuffix .key,$(addprefix .id_rsa_, $(HOSTS)))

ssh-%:
	@ssh -i ${PWD}/.id_rsa_$*.key -t pirate@$*.local ${ARGS}

port-vars: $(addprefix port-ips-,$(HOST_PREFIXES))
port-ips-%:
	$(eval port_ips_$* = $(shell ./util/bonjour_to_ip_json.sh $(HOSTS) | jq '.[] | select(.hostname | startswith("$*")) | .ip'))
	@if [[ "$(port_ips_$*)" == "" ]]; then echo "ERROR: could not get IP for $*" ; exit 1 ; else \
		echo $(port_ips_$*) ; \
	fi


certs: port-vars
	@mkdir -p certs
	$(eval MASTER_CERTS := $(shell H=($(MASTER_NODES)) IPS=($(port_ips_kpi-master)) ; for i in "$${!IPS[@]}"; do echo $${H[$$i]/.local/},$${IPS[$$i]},$(SERVICE_CLUSTER_IP),localhost,127.0.0.1.pem; done))
	$(eval WORKER_CERTS := $(shell H=($(WORKER_NODES)) IPS=($(port_ips_kpi-worker)) ; for i in "$${!IPS[@]}"; do echo $${H[$$i]/.local/},$${IPS[$$i]},$(SERVICE_CLUSTER_IP),localhost,127.0.0.1.pem; done))
	$(MAKE) $(addprefix certs/,$(MASTER_CERTS)) $(addprefix certs/,$(WORKER_CERTS))
	cp ca.pem certs/ca.pem

test-certs: $(addprefix test-cert-,$(subst .local,,$(HOSTS)))
test-cert-%:
	openssl x509 -in $(shell ls certs/$*,*,127.0.0.1.pem) -noout -text

copy-certs: $(addprefix copy-certs-,$(subst .local,,$(HOSTS)))
copy-certs-%:
	scp -r -i ${PWD}/.id_rsa_$*.key certs/ca.pem pirate@$*.local:~/ca.pem
	scp -r -i ${PWD}/.id_rsa_$*.key certs/$*,*,127.0.0.1.pem pirate@$*.local:~/kubernetes.pem
	scp -r -i ${PWD}/.id_rsa_$*.key certs/$*,*,127.0.0.1-key.pem pirate@$*.local:~/kubernetes-key.pem

copy-scripts: $(addprefix copy-scripts-,$(subst .local,,$(HOSTS)))
copy-scripts-%:
	scp -i ${PWD}/.id_rsa_$*.key scripts/* pirate@$*.local:~/

bin-files: bin/etcd bin/etcdctl bin/hyperkube cni

copy-files-%: copy-certs-% copy-scripts-% copy-etcd-% copy-hyperkube-% copy-cni-%
	$(warning copied files to $*)

stop-workers: $(addprefix stop-worker-,$(subst .local,,$(WORKER_NODES)))
stop-worker-%:
	ssh -i ${PWD}/.id_rsa_$*.key -t pirate@$*.local 'sudo systemctl stop kube-proxy && sudo systemctl stop kubelet'

stop-masters: $(addprefix stop-master-,$(subst .local,,$(MASTER_NODES)))
stop-master-%: $(addprefix stop-master-,$(subst .local,,$(MASTER_NODES)))
	ssh -i ${PWD}/.id_rsa_$*.key -t pirate@$*.local 'sudo systemctl stop kube-scheduler && sudo systemctl stop kube-controller-manager && sudo systemctl stop kube-apiserver && sudo systemctl stop etcd'

clean-etcd-%:
	ssh -i ${PWD}/.id_rsa_$*.key -t pirate@$*.local 'sudo rm -Rf /var/lib/etcd/member'

include cfssl.mk
include etcd.mk
include hyperkube.mk
include cni.mk
