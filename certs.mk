
.PHONY: certs

CFSSL=/usr/local/bin/cfssl
CFSSLJSON=/usr/local/bin/cfssljson

gen-certs: certs/ca.pem certs/kubernetes-csr.json certs/kubernetes-key.pem copy-certs

copy-certs: $(addprefix copy-certs-,$(HOSTS))

copy-certs-%:
	scp -i ${PWD}/.id_rsa_$*.key certs/{ca,kubernetes-key,kubernetes}.pem pirate@$*.local:~/

certs/ca.pem: $(CFSSL) $(CFSSLJSON)
	cd certs && cfssl gencert -initca ca-csr.json | cfssljson -bare ca
	cd certs && openssl x509 -in ca.pem -text -noout

certs/kubernetes-key.pem:
	cd certs && cfssl gencert \
	  -ca=ca.pem \
	  -ca-key=ca-key.pem \
	  -config=ca-config.json \
	  -profile=kubernetes \
	  kubernetes-csr.json | cfssljson -bare kubernetes && \
		openssl x509 -in kubernetes.pem -text -noout
