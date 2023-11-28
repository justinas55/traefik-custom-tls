#!/bin/bash

set -o xtrace

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo "Usage: ./gen-client-cert.sh <server CN> <server cert name> <client cert name>"
    echo "Example: ./gen-client-cert.sh example.localhost server client1"
    exit 1
fi

RSA_BITS=4096
CLIENT_NAME=$3
CLIENT_CERT_DAYS=750
CLIENT_CN=$3
SERVER_CERT_CN=$1
SERVER_CERT_NAME=$2

mkdir -p certs/clients
client_cert_file=certs/clients/$CLIENT_NAME
openssl genrsa -out $client_cert_file.key $RSA_BITS
openssl req -new -key $client_cert_file.key -out $client_cert_file.csr -sha256 -subj "/CN=$CLIENT_CN" -addext "subjectAltName=DNS:$CLIENT_CN"
echo "
[client]
basicConstraints = CA:FALSE
nsCertType = client, email
nsComment = "Client $CLIENT_CN cert for $SERVER_CERT_CN"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth, emailProtection
" > $client_cert_file.cnf
openssl x509 -req -days $CLIENT_CERT_DAYS -in $client_cert_file.csr -sha256 -CA certs/$SERVER_CERT_NAME.crt -CAkey certs/$SERVER_CERT_NAME.key -CAcreateserial -out $client_cert_file.crt -extfile $client_cert_file.cnf -extensions client
cat $client_cert_file.key $client_cert_file.crt certs/$SERVER_CERT_NAME.crt > $client_cert_file.pem
openssl pkcs12 -export -keypbe NONE -certpbe NONE -nomaciter -passout pass:"" -passin pass:"" -out $client_cert_file.pfx -inkey $client_cert_file.key -in $client_cert_file.pem -certfile certs/$SERVER_CERT_NAME.crt

