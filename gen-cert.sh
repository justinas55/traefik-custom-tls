#!/bin/bash

RSA_BITS=2048
CERT_DAYS=3650

while [[ $# -gt 0 ]]; do
    case $1 in
    -f | --force)
        force=1
        shift # past argument
        ;;
    --ca)
        ca="$2"
        if [ ! -f "certs/${ca}.crt" ]; then
            echo "CA does not exist: certs/${ca}.crt"
            exit 1
        fi

        shift # past argument
        shift # past value
        ;;
    --cn)
        cn="$2"

        shift # past argument
        shift # past value
        ;;
    --bits)
        RSA_BITS=$2
        shift # past argument
        shift # past value
        ;;
    --days)
        CERT_DAYS=$2
        shift # past argument
        ;;
    -* | --*)
        echo "Unknown option $1"
        exit 1
        ;;
    *)
        POSITIONAL_ARGS+=("$1") # save positional arg
        shift                   # past argument
        ;;
    esac
done
set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

type=$1
name=$2
cn=${cn:-$name}

if [ -z "$type" ] || [ -z "$name" ]; then
    echo "Usage: ./gen-cert.sh [-f] [--ca <ca>] [--cn <cn>] [--bits <bits>] [--days <days>] [-ca <ca name>] <ca|server|client> <name>"
    echo "Example: ./gen-cert.sh -f --ca example.localhost.clients-ca client device1"
    exit 1
fi

filename="certs/${name}"
if [ -f "$filename" ] && [ "$force" != "1" ]; then
    echo "Already exists: $filename"
    exit 1
fi

if [ -z "$cn" ] && [ "$type" != "ca" ]; then
    echo "CN must be specified"
fi

mkdir -p certs

openssl genrsa -out "${filename}.key" $RSA_BITS

if [ "$type" == "ca" ]; then
    # 1. Generate CA key and certificate

    if [ -z "$ca" ]; then
        openssl req -x509 -new -nodes -key "${filename}.key" -days $CERT_DAYS -out "${filename}.crt" -subj "/CN=$cn"
    else
        ca_filename="certs/$ca"
        im_ca_filename=$filename
        openssl genrsa -out "${im_ca_filename}.key" $RSA_BITS
        echo "
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:TRUE
keyUsage = keyCertSign, cRLSign, digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
" >$im_ca_filename.cnf
        openssl req -new -key "${im_ca_filename}.key" -out "${im_ca_filename}.csr" -subj "/CN=$cn"
        openssl x509 -req -in "${im_ca_filename}.csr" -CA "${ca_filename}.crt" -CAkey "${ca_filename}.key" -CAcreateserial -out "$im_ca_filename.crt" -days $CERT_DAYS -extfile $im_ca_filename.cnf
        cat "${im_ca_filename}.crt" "${ca_filename}.crt" >"${im_ca_filename}.chain"
    fi
elif [ "$type" == "server" ]; then
    ca_filename="certs/$ca"
    server_cert_filename=$filename
    # 3. Generate Server key, certificate and chain (signed by CA)
    openssl genrsa -out "${server_cert_filename}.key" $RSA_BITS
    openssl req -new -key "${server_cert_filename}.key" -out "${server_cert_filename}.csr" -subj "/CN=$cn"
    echo "
subjectAltName=DNS:$cn
" >$server_cert_filename.cnf
    openssl x509 -req -in "${server_cert_filename}.csr" -CA "${ca_filename}.crt" -CAkey "${ca_filename}.key" -CAcreateserial -out "${server_cert_filename}.crt" -days $CERT_DAYS -extfile $server_cert_filename.cnf
    cat "${server_cert_filename}.crt" "${ca_filename}.crt" >"${server_cert_filename}.chain"
elif [ "$type" == "client" ]; then
    ca_filename="certs/$ca"
    client_cert_file=$filename

    openssl req -new -key $client_cert_file.key -out $client_cert_file.csr -sha256 -subj "/CN=$cn" -addext "subjectAltName=DNS:$cn"
    echo "
[client]
basicConstraints = CA:FALSE
nsCertType = client, email
nsComment = "Client $cn cert for $ca"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth, emailProtection
" >$client_cert_file.cnf

    openssl x509 -req -days $CERT_DAYS -in $client_cert_file.csr -sha256 -CA $ca_filename.crt -CAkey $ca_filename.key -CAcreateserial -out $client_cert_file.crt -extfile $client_cert_file.cnf -extensions client
    cat $client_cert_file.key $client_cert_file.crt $ca_filename.crt >$client_cert_file.pem
    openssl pkcs12 -export -keypbe NONE -certpbe NONE -nomaciter -passout pass:"" -passin pass:"" -out $client_cert_file.pfx -inkey $client_cert_file.key -in $client_cert_file.pem -certfile $ca_filename.crt
fi
