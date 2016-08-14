HYPERKUBE_ARM_IMAGE := gcr.io/google_containers/hyperkube-arm:v1.3.5

bin/hyperkube:
	@mkdir -p bin
	docker create --name hyperkube-arm $(HYPERKUBE_ARM_IMAGE)
	docker cp hyperkube-arm:/hyperkube bin/hyperkube
	docker rm hyperkube-arm

copy-hyperkube-%:
	scp -i ${PWD}/.id_rsa_$*.key bin/hyperkube pirate@$*.local:~/
