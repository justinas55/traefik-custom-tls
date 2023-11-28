#!/bin/bash

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: ./gen-server-cert.sh <server CN> <name>"
    echo "Example: ./gen-server-cert.sh example.localhost server"
    exit 1
else
    cn=$1
    name=$2
fi

RSA_BITS=4096
SERVER_CERT_DAYS=3650
SERVER_CERT_CN=$cn
CLIENT_CERT_DAYS=750

mkdir -p certs
cert_filename=certs/$name
openssl req -x509 -newkey rsa:$RSA_BITS -sha256 -days $SERVER_CERT_DAYS -nodes -keyout $cert_filename.key -out $cert_filename.crt -subj "/CN=$SERVER_CERT_CN" -addext "subjectAltName=DNS:$SERVER_CERT_CN"
