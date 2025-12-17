#!/bin/bash

## Script to check if the most recent folio import failed
## Exit Codes:
##   0: OK
##   1: WARNING
##   2: CRITICAL
##   3: UNKNOWN

if [[ -z "$1" ]]; then
    echo "UNKNOWN: You must provide a deployment name (e.g. catprod-beta) as the first argument."
    exit 3
fi

# Stack deployment name (e.g. catprod-beta, devel-nathan)
DEPLOYMENT="$1"

if ! OUTPUT=$(pc-check-exit-code -f /home/nagios/"${DEPLOYMENT}"/logs/harvests/authority_exit_code -l /home/nagios/"${DEPLOYMENT}"/logs/harvests/authority.log -v 2>&1); then
    echo "CRITICAL"
    echo "${OUTPUT}"
    exit 2
else
    echo "OK"
    echo "${OUTPUT}"
    exit 0
fi

