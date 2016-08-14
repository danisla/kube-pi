.PHONY: cni

TEMP_DIR=${PWD}
CNI_RELEASE=9d5e6e60e79491207834ae8439e80c943db65a69
ARCH=arm

cni:
	@mkdir -p bin
	docker run -it -v ${TEMP_DIR}/cni:/cnibin golang:1.6 /bin/bash -c "\
		git clone https://github.com/containernetworking/cni \
		&& cd cni \
		&& git checkout $(CNI_RELEASE) \
		&& GOARCH=$(ARCH) ./build \
		&& cp bin/* /cnibin"

copy-cni: $(addprefix copy-cni-,$(HOSTS))
copy-cni-%:
	scp -r -i ${PWD}/.id_rsa_$*.key cni pirate@$*.local:~/
