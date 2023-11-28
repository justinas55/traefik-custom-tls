# Traefik mTLS (Client certificate authentication) - Proof of concept docker-compose project

This project is a minimal setup of Traefik with two HTTP services that are authenticated with mTLS / Client certificates.

Repository is fully configured and ready for test environment: `docker-compose up` should be enough.

## Testing locally (Linux shell)

- Bring up docker compose project: `docker-compose up &`

### Works with correct client certificate
- Run `curl -k --resolve example.localhost:443:127.0.0.1 --cert certs/clients/client.crt --key certs/clients/client.key https://example.localhost/bench` - should return '1' if service responds successfully

### Works with another correct client certificate
- Run `curl -k --resolve example.localhost:443:127.0.0.1 --cert certs/clients/client2.crt --key certs/clients/client2.key https://example.localhost/bench` - should return '1' if service responds successfully

### Fails without client certificate
- Run `curl -k --resolve example.localhost:443:127.0.0.1 https://example.localhost/bench` - should fail with:
  ```
  curl: (56) OpenSSL SSL_read: error:0A00045C:SSL routines::tlsv13 alert certificate required, errno 0
  ```

### Fails with client certificate with bad CA
- Run `curl -k --resolve example.localhost:443:127.0.0.1 --cert certs/clients/clientnew.crt --key certs/clients/clientnew.key https://example.localhost/bench` - should fail with:
  ```
  curl: (56) OpenSSL SSL_read: error:0A000418:SSL routines::tlsv1 alert unknown ca, errno 0
  ```

## Certificate update

Example procedure to update certificates in testing environment. 

- Bring up docker compose project: `docker-compose up`
- Run `curl -k --resolve example.localhost:443:127.0.0.1 --cert certs/clients/clientnew.crt --key certs/clients/clientnew.key https://example.localhost/bench` - should fail and not return '1'
- Enable Traefik to also accept client certs from new CA: edit `conf/tls.yml` and uncomment line:
  ```
    caFiles:
      - /etc/traefik/certs/server.crt
      - /etc/traefik/certs/servernew.crt
  ```
- Run `curl -k --resolve example.localhost:443:127.0.0.1 --cert certs/clients/clientnew.crt --key certs/clients/clientnew.key https://example.localhost/bench` - should now succeed and return '1'
- Run `curl -k --resolve example.localhost:443:127.0.0.1 --cert certs/clients/client.crt --key certs/clients/client.key https://example.localhost/bench` - old cert should also succeed and return '1'
- Disable old CA client certs: edit `conf/tls.yml` and comment line:
  ```
    caFiles:
      #- /etc/traefik/certs/server.crt
      ...
  ```
- Run `curl -k --resolve example.localhost:443:127.0.0.1 --cert certs/clients/client.crt --key certs/clients/client.key https://example.localhost/bench` - old cert should fail and not return '1'

## Certificates

All certificates for tests in this README are included, but if needed there are two util scripts for generating certs:
- `./gen-server-cert.sh <server CN> <server cert name>` - generate server certificate
- `./gen-client-cert.sh <server CN> <server cert name> <client cert name>` - generate client certificate

To generate certificates for testing:
```
# server certificate (this generates `certs/server.crt` with 'example.localhost' common name which is already specified in example Traefik config)
./gen-server-cert.sh example.localhost server

# client certificate for test client
./gen-client-cert.sh example.localhost server client

# client certificate for second test client
./gen-client-cert.sh example.localhost server client2

# new server certificate
./gen-server-cert.sh example.localhost servernew

# client certificate for test client on new server CA
./gen-client-cert.sh example.localhost servernew clientnew
```