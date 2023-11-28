# Traefik mTLS (Client certificate authentication) - Proof of concept docker-compose project

This project is a minimal setup of Traefik with two HTTP services that are authenticated with mTLS / Client certificates.

Repository is fully configured and ready for test environment: `docker-compose up` should be enough.

## Testing locally (Linux shell)

- Bring up docker compose project: `docker-compose up &`

### Works with correct client certificate and CA
- Run `curl --cacert certs/CA1.crt --resolve svc1.main.example.localhost:443:127.0.0.1 --cert certs/device1.crt --key certs/device1.key https://svc1.main.example.localhost/bench` - should return '1' if service responds successfully

### Test connectivity works with correct client certificate and CA
- Run `curl --cacert certs/CA1.crt --resolve test.example.localhost:443:127.0.0.1 --cert certs/device1.crt --key certs/device1.key https://test.example.localhost/bench` - should return '1' if service responds successfully

### Test connectivity fails with another CA
- Run `curl --cacert certs/CA2.crt --resolve test.example.localhost:443:127.0.0.1 --cert certs/device1.crt --key certs/device1.key https://test.example.localhost/bench` - should fail with:
  ```
  curl: (60) SSL certificate problem: unable to get local issuer certificate
  ```

### Works with another correct client certificate
- Run `curl --cacert certs/CA1.crt --resolve svc1.main.example.localhost:443:127.0.0.1 --cert certs/device2.crt --key certs/device2.key https://svc1.main.example.localhost/bench` - should return '1' if service responds successfully

### Fails without client certificate
- Run `curl --cacert certs/CA1.crt --resolve svc1.main.example.localhost:443:127.0.0.1 https://svc1.main.example.localhost/bench` - should fail with:
  ```
  curl: (56) OpenSSL SSL_read: error:0A00045C:SSL routines::tlsv13 alert certificate required, errno 0
  ```

### Fails with client certificate with bad CA
- Run `curl --cacert certs/CA1.crt --resolve svc1.main.example.localhost:443:127.0.0.1 --cert certs/new.device1.crt --key certs/new.device1.key https://svc1.main.example.localhost/bench` - should fail with:
  ```
  curl: (56) OpenSSL SSL_read: error:0A000418:SSL routines::tlsv1 alert unknown ca, errno 0
  ```

### Fails with bad server CA
- Run `curl --cacert certs/CA2.crt --resolve svc1.main.example.localhost:443:127.0.0.1 --cert certs/device1.crt --key certs/device1.key https://svc1.main.example.localhost/bench` - should fail with:
  ```
  curl: (60) SSL certificate problem: unable to get local issuer certificate
  ```

## Certificate update

During update clients must trust old and new CA, and server mTLS configuration also must trust both old and new client certificates.
As extra safety, server has extra endpoint with new certificate that is used by clients only for 'testing connectivity' function.

All services use wildcard server certificate with CN `*.main.example.localhost`. 
Test connectivity service uses separate `test.example.localhost` which can be updated separately avoiding disruption of other services.

1) Generate new certificate chain: CA, IM CA, Server
2) Reconfigure Traefik test endpoint to use new server certificate - comment old test endpoint cert and uncomment new test endpoint cert (see tls.yml)
3) Reconfigure Traefik mTLS to now trust both old and new CA (or IM-CA) client certificates - uncomment `CA2-clients-ICA` in clientAuth section (see tls.yml)
4) Distribute and install CA and client certificates to clients - clients should trust both old and new CA at this point
5) Make sure all clients are updated - test connection to test server endpoint from all clients
  Can be tested with:
  ```
  # Main services still use old CA1
  curl --cacert certs/CA1.crt --resolve svc1.main.example.localhost:443:127.0.0.1 --cert certs/device1.crt --key certs/device1.key https://svc1.main.example.localhost/bench
  # But new CA2 client certs now authenticate successfully
  curl --cacert certs/CA1.crt --resolve svc1.main.example.localhost:443:127.0.0.1 --cert certs/new.device1.crt --key certs/new.device1.key https://svc1.main.example.localhost/bench
  # Test connectivity endpoint should use CA2
  curl --cacert certs/CA2.crt --resolve test.localhost:443:127.0.0.1 --cert certs/new.device1.crt --key certs/new.device1.key https://test.example.localhost/bench
  ```
6) Switch server certificate to new on main endpoint - in tls.yml switch `main.example.localhost` to `new.main.example.localhost`, and disable `CA1-clients-ICA` in clientAuth section (see tls.yml)
  ```
  # Main services now use new CA2
  curl --cacert certs/CA2.crt --resolve svc1.main.example.localhost:443:127.0.0.1 --cert certs/new.device1.crt --key certs/new.device1.key https://svc1.main.example.localhost/bench
  # Test connectivity endpoint should use CA2
  curl --cacert certs/CA2.crt --resolve test.localhost:443:127.0.0.1 --cert certs/new.device1.crt --key certs/new.device1.key https://test.example.localhost/bench
  # Old CA and certs now should fail:
  curl --cacert certs/CA2.crt --resolve svc1.main.example.localhost:443:127.0.0.1 --cert certs/device1.crt --key certs/device1.key https://svc1.main.example.localhost/bench
  curl --cacert certs/CA1.crt --resolve svc1.main.example.localhost:443:127.0.0.1 --cert certs/new.device1.crt --key certs/new.device1.key https://svc1.main.example.localhost/bench
  ```
7) Delete old CA from all clients

## Certificates (with CA and intermediate CA)

CA1 ----> main.example.localhost
    \-- > test.example.localhost
     \--> CA1-clients-ICA ------------> device1
                                \-----> device2

CA2 ----> new.main.example.localhost
    \-- > new.test.example.localhost
     \--> CA2-clients-ICA ------------> new.device1

To generate certificates for testing:
```
# main certificate chain: CA, intermediate CA and server (signed by CA not intermediate)
./gen-cert.sh ca CA1
./gen-cert.sh ca --ca CA1 CA1-clients-ICA
./gen-cert.sh server --ca CA1 --cn *.main.example.localhost main.example.localhost
./gen-cert.sh server --ca CA1 test.example.localhost

# client certificate for intermediate CA
./gen-cert.sh client --ca CA1-clients-ICA device1

# client2 certificate for intermediate CA
./gen-cert.sh client --ca CA1-clients-ICA device2

# test/alternative certificate chain: CA, intermediate CA and server (signed by CA not intermediate)
./gen-cert.sh ca CA2
./gen-cert.sh ca --ca CA2 CA2-clients-ICA
./gen-cert.sh server --ca CA2 --cn *.main.example.localhost new.example.localhost
./gen-cert.sh server --ca CA2 --cn test.example.localhost new.test.example.localhost

# client certificate for test intermediate CA
./gen-cert.sh client --ca CA2-clients-ICA new.device1
```

## Other commands

- Show certificates returned by server endpoint: `openssl s_client -showcerts -connect localhost:443 -servername test.example.localhost`
