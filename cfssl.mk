CA_NAME := kubernetes
O := kubernetes.local
COUNTRY := US
CITY := Pasadena
OU := CA
STATE := California

CFSSL := /usr/local/bin/cfssl
CFSSLJSON := /usr/local/bin/cfssljson

%.pem: $(CFSSL) $(CFSSLJSON) ca.pem
	@echo '{"CN":"$(notdir $*)","hosts":["$*"],"key":{"algo":"rsa","size":2048}}' \
    | cfssl gencert \
      -ca=ca.pem \
      -ca-key=ca-key.pem \
      -config=ca-config.json \
      -profile=$(CA_NAME) \
      -hostname=$(notdir $*) - \
        | cfssljson -bare $*

ca.pem: ca-config.json ca-csr.json
	cfssl gencert -initca ca-csr.json | cfssljson -bare ca

$(CFSSL):
	$(warning downloading cfssl binary to $(CFSSL))
	curl -Lsf https://pkg.cfssl.org/R1.2/cfssl_darwin-amd64 > $(CFSSL)
	chmod +x $(CFSSL)

$(CFSSLJSON):
	$(warning downloading cfssl binary to $(CFSSLJSON))
	curl -Lsf https://pkg.cfssl.org/R1.2/cfssljson_darwin-amd64 > $(CFSSLJSON)
	chmod +x $(CFSSLJSON)

ca-config.json:
	$(warning generating ca-config.json)
	@echo '{"signing":{"default":{"expiry":"8760h"},"profiles":{"$(CA_NAME)":{"usages":["signing","key encipherment","server auth","client auth"],"expiry":"8760h"}}}}' \
	    > ca-config.json

ca-csr.json:
	$(warning generating ca-csr.json)
	@echo '{"CN":"$(CA_NAME)","key":{"algo":"rsa","size":2048},"names":[{"C":"$(COUNTRY)","L":"$(CITY)","O":"$(O)","OU":"$(OU)","ST":"$(STATE)"}]}' \
	    > ca-csr.json

clean-certs:
	rm -f *.pem *.csr ca-csr.json ca-config.json
