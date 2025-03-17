#!/bin/bash

set -e

declare -i LARGE_VUFIND_LOG_KB=128
declare -i LARGE_APACHE_LOG_KB=256

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

# Find local VuFind container; we'll use it to see the logs
declare VUFIND_NAME=
while read -r LINE; do
    if [[ "$LINE" == "${DEPLOYMENT}-catalog_catalog"* ]]; then
        VUFIND_NAME="$LINE"
        break;
    fi
done < <( docker_sudo docker container ls -f "status=running" -f "name=${DEPLOYMENT}-" --format "{{ .Names }}" )

# Fail if we can't find the VuFind container
if [ -z "$VUFIND_NAME" ]; then
    echo "UNKNOWN: No running VuFind container found on the current node."
    exit 3
fi

declare APACHE_ERROR_FILE="/var/log/apache2/error.log"
declare VUFIND_LOG_FILE="/var/log/vufind/vufind.log"
logfiles_are_readable() {
    for FILE in "$APACHE_ERROR_FILE" "$VUFIND_LOG_FILE"; do
        if docker_sudo docker exec -t "$VUFIND_NAME" bash -c "[[ ! -f $FILE ]] || [[ ! -r $FILE ]]"; then
            return 1
        fi
    done
    return 0
}

human_file_size() {
    docker_sudo docker exec -t "$VUFIND_NAME" du -h "$1" | cut -f1 -
}

file_size() {
    docker_sudo docker exec -t "$VUFIND_NAME" stat -c%s "$1" | tr -d '\r\n'
}

file_size_greater_than() {
    declare FILE="$1"
    declare -i MAX_SIZE_KB="$2"
    FILE_KB=$(( $(file_size "$FILE") / 1024 ))
    [[ $FILE_KB -gt $MAX_SIZE_KB ]]
}

vufind_logfile_is_large() {
    file_size_greater_than "$VUFIND_LOG_FILE" "$LARGE_VUFIND_LOG_KB"
}

apache_errorlog_is_large() {
    file_size_greater_than "$APACHE_ERROR_FILE" "$LARGE_APACHE_LOG_KB"
}

if ! logfiles_are_readable; then
    echo "CRITICAL: Could not find or access log files!"
    exit 2
elif vufind_logfile_is_large; then
    echo "WARNING: vufind/vufind.log size is large ($(human_file_size "$VUFIND_LOG_FILE")); check the logs for problems."
    exit 1
elif apache_errorlog_is_large; then
    echo "WARNING: apache2/error.log size is large ($(human_file_size "$APACHE_ERROR_FILE")); check the logs for problems."
    exit 1
fi

echo "Logs check OK for $DEPLOYMENT"
exit 0
