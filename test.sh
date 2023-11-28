#!/bin/bash

set -x

goodcert=certs/clients/client1
badcert=certs/clients/client2

echo "Testing with client certificate..."
if [ "1" != "$(curl -k --resolve example.localhost:443:127.0.0.1 --cert $goodcert.crt --key $goodcert.key https://example.localhost/bench)" ]; then
    echo "Failed"
    exit 1
fi
echo "OK"

echo "Testing without client certificate..."
if ! curl -k --resolve example.localhost:443:127.0.0.1 https://example.localhost/bench 2>&1| grep -q 'alert certificate required'; then
    echo "Failed"
    exit 1
fi
echo "OK"

echo "Testing with bad client certificate..."
#if ! curl -k --resolve example.localhost:443:127.0.0.1 https://example.localhost/bench 2>&1| grep -q 'alert certificate required'; then
if [ "1" == "$(curl -k --resolve example.localhost:443:127.0.0.1 --cert $badcert.crt --key $badcert.key https://example.localhost/bench)" ]; then
    echo "Failed"
    exit 1
fi
echo "OK"

echo "Tests passed"