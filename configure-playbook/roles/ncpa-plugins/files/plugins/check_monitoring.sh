#!/bin/bash

# Prepend sudo to a command if user is not in docker group
docker_sudo() {
    if ! groups | grep -qw docker; then sudo "$@";
    else "$@"; fi
}

if [[ -z "$1" ]]; then
    echo "UNKNOWN: You must provide a deployment name (e.g. catalog-beta) as the first argument."
    exit 3
fi

DEPLOYMENT="$1"

# Find local container
MONITORING_CONTAINER=
while read -r MONITORING_CONTAINER; do
    break   # should only be one match anyways
done < <( docker_sudo docker container ls -f "status=running" -f "name=${DEPLOYMENT}-monitoring_monitoring." --format "{{ .Names }}" )

if [[ -z "$MONITORING_CONTAINER" ]]; then
    echo "CRITICAL: Cannot find a local Monitoring container for stack $DEPLOYMENT."
    exit 2
fi

# Find local proxysolr container
PROXYSOLR_CONTAINER=
while read -r PROXYSOLR_CONTAINER; do
    break   # should only be one match anyways
done < <( docker_sudo docker container ls -f "status=running" -f "name=${DEPLOYMENT}-solr_proxysolr." --format "{{ .Names }}" )

if [[ -z "$PROXYSOLR_CONTAINER" ]]; then
    echo "CRITICAL: Cannot find a local proxysolr container for stack $DEPLOYMENT."
    exit 2
fi

run_getent_hosts() {
    # shellcheck disable=SC2016
    docker_sudo docker exec -i --env HOSTCHECK="$1" "${2:-$MONITORING_CONTAINER}" sh -c 'getent hosts "$(eval echo $HOSTCHECK)" > /dev/null'
}

# Verify the container can resolve the hostname of itself
if ! run_getent_hosts "monitoring"; then
    echo "WARNING: Could not resolve host monitoring from within monitoring container."
    exit 1
fi
# Verify the container can resolve the hostname of proxysolr
if ! run_getent_hosts "proxysolr"; then
    echo "WARNING: Could not resolve host proxysolr from within monitoring container."
    exit 1
fi
# Verify the proxysolr container can resolve the hostname of monitoring
if ! run_getent_hosts "monitoring" "$PROXYSOLR_CONTAINER"; then
    echo "WARNING: Could not resolve host monitoring from within proxysolr container."
    exit 1
fi

echo "Monitoring status OK for $DEPLOYMENT"
exit 0
