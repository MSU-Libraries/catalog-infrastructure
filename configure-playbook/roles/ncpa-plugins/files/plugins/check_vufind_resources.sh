#!/bin/bash

# shellcheck disable=SC2317 # Incorrect warning the commands are unreachable

## Script to check the Memory and CPU usage of the VuFind container
## which helps identify when bot attacks are occurring.

# Prepend sudo to a command if user is not in docker group
docker_sudo() {
    if ! groups | grep -qw docker; then sudo "$@";
    else "$@"; fi
}

if [[ -z "$1" ]]; then
    echo "UNKNOWN: You must provide a deployment name (e.g. catprod-beta) as the first argument."
    exit 3
fi

# Stack deployment name (e.g. catprod-beta, devel-nathan)
DEPLOYMENT="$1"

# Verify that the numerical stat output for the given resource is less than the
# provided warning and critical values and exit with the appropriate code.
verify_resource() {
    # Ex: MemPerc, CPUPerc (found in docker stats --no-stream --no-trunc --format json [container])
    RESOURCE="$1"
    WARN="$2" # Numerical cut off when a warning should be triggered (i.e. 10)
    CRIT="$3" # Numerical cut off when a critical error should be triggered (i.e. 15)

    STAT=$( docker_sudo docker stats --no-stream --format "{{.${RESOURCE}}}" "$(docker_sudo docker ps -q -f name="${DEPLOYMENT}"-catalog_catalog)")

    if [[ -z "$STAT" ]]; then
        echo "UNKNOWN: Could not get ${RESOURCE} in VuFind container for ${DEPLOYMENT}"
        exit 3
    fi
    
    NORMALIZED_STAT=$(printf '%.*f\n' 0 "${STAT//\%/}")
    MESSAGE="${RESOURCE} for ${DEPLOYMENT} VuFind container is ${STAT}"

    # shellcheck disable=SC2004 # check is not correctly realizing that the $ is required when in the if-statement
    if (( $NORMALIZED_STAT > $CRIT )); then
        echo "CRITICAL: ${MESSAGE}"
        exit 2
    elif (( $NORMALIZED_STAT > $WARN )); then
        echo "WARNING: ${MESSAGE}"
        exit 1
    else
        echo "OK: ${MESSAGE}"
    fi
}

verify_resource "CPUPerc" 85 95
verify_resource "MemPerc" 85 95

exit 0
