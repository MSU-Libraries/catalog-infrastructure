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

is_main() {
    [[ "$DEPLOYMENT" == "catalog"* || "$DEPLOYMENT" == "catprod"* ]]
    return $?
}

is_url_test_api() {
    [[ "$1" == *"test.folio"* ]]
    return $?
}

# Find local VuFind container
VUFIND_NAME=
while read -r LINE; do
    if [[ "$LINE" == "${DEPLOYMENT}-catalog_catalog"* ]]; then
        VUFIND_NAME="$LINE"
        break;
    fi
done < <( docker_sudo docker container ls -f "status=running" -f "name=${DEPLOYMENT}-" --format "{{ .Names }}" )

# Find local VuFind Cron container
CRON_NAME=
while read -r LINE; do
    if [[ "$LINE" == "${DEPLOYMENT}-catalog_cron"* ]]; then
        CRON_NAME="$LINE"
        break;
    fi
done < <( docker_sudo docker container ls -f "status=running" -f "name=${DEPLOYMENT}-" --format "{{ .Names }}" )

cron_is_disabled() {
    # Only detect disabled if cron container exists on this host
    if [[ -n "$CRON_NAME" ]]; then
        DISABLED=$( docker_sudo docker exec -t "$CRON_NAME" find -L /mnt/oai -mindepth 1 -maxdepth 1 -type f -iname 'disabled' | wc -l )
        if [[ "$DISABLED" -gt 0 ]]; then
            return 0
        fi
    fi
    return 1
}

folio_api_url() {
    docker_sudo docker exec -t "$VUFIND_NAME" cat /usr/local/vufind/local/config/vufind/folio.ini | grep -E "^ *base_url *=" | head -n1 | cut -d= -f2- | sed 's/ *$//' | sed 's/^ *//'
}

oai_api_url() {
    docker_sudo docker exec -t "$VUFIND_NAME" cat /usr/local/vufind/local/harvest/oai.ini | grep -E "^ *url *=" | head -n1 | cut -d= -f2- | sed 's/[" \n\r]*$//' | sed 's/^[" ]*//'
}

# Validate API URLs match their environments
FOLIO_API_URL=$( folio_api_url )
OAI_API_URL=$( oai_api_url )
if [[ -z "$FOLIO_API_URL" ]]; then
    echo "CRITICAL: Could not find FOLIO API URL in configuration!"
    exit 2
elif is_url_test_api "$FOLIO_API_URL" && is_main; then
    echo "CRITICAL: FOLIO configuration is pointing to the TEST environment!"
    exit 2
elif ! is_url_test_api "$FOLIO_API_URL" && ! is_main; then
    echo "CRITICAL: Non-main FOLIO configuration is NOT pointing to TEST environment!"
    exit 2
fi
if [[ -z "$OAI_API_URL" ]]; then
    echo "CRITICAL: Could not find OAI API URL in configuration!"
    exit 2
elif is_url_test_api "$OAI_API_URL" && is_main; then
    echo "CRITICAL: OAI configuration is pointing to the TEST environment!"
    exit 2
elif ! is_url_test_api "$OAI_API_URL" && ! is_main; then
    echo "WARNING: Non-main OAI configuration is NOT pointing to TEST environment!"
    exit 1
fi

# Check for disabled OAI harvesting
if is_main && cron_is_disabled; then
    echo "WARNING: OAI harvesting has been disabled for $DEPLOYMENT!"
    exit 1
fi

echo "FOLIO status check OK for $DEPLOYMENT"
exit 0
