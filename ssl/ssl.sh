#!/bin/bash
openssl genrsa -des3 -passout pass:password -out localdomain.secure.key 2048     && echo "password" |openssl rsa -in localdomain.secure.key -out localdomain.insecure.key -passin stdin
openssl req -new -sha256 -nodes -out localdomain.csr -key localdomain.insecure.key -config localdomain.csr.cnf
openssl genrsa -des3 -passout pass:password -out rootca.secure.key 2048 && echo "password" | openssl rsa -in rootca.secure.key -out rootca.insecure.key -passin stdin
openssl req -new -x509 -nodes -key rootca.insecure.key -sha256 -out cacert.pem -days 3650 -subj "/C=GB/ST=London/L=London/O=ZZ/OU=IT Department/CN=Testing"
openssl x509 -req -in localdomain.csr -CA cacert.pem -CAkey rootca.insecure.key -CAcreateserial -out localdomain.crt -days 500 -sha256 -extfile localdomain.v3.ext
