#!/bin/bash

exec curl --fail --silent --output /dev/null --max-time 1 \
    --cacert /data/caddy/pki/authorities/local/root.crt \
    https://caddy.localhost/healthz
