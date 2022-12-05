#!/bin/bash

if [[ -z "$1" ]]; then
    echo "INVALID: Must pass a deployment name to check_docker.sh."
    exit 2
fi

DEPLOYMENT="$1"
MARIADB_USER="${2:-root}"
MARIADB_PASS="${3:-12345}"

# Find local MariaDB container
MARIADB_NAME=
while read -r LINE; do
    if [[ "$LINE" == "${DEPLOYMENT}-mariadb_galera"* ]]; then
        MARIADB_NAME="$LINE"
        break;
    fi
done < <( sudo docker container ls -f "status=running" -f "name=${DEPLOYMENT}-" --format "{{ .Names }}" )

if [[ -z "$MARIADB_NAME" ]]; then
    echo "CRITICAL: Cannot find MariaDB container for given stack."
    exit 2
fi

run_sql() {
    FILTER="${2}"
    echo "$1" | docker exec -i ${MARIADB_NAME} mysql -u${MARIADB_USER} -p${MARIADB_PASS} vufind | grep "$FILTER"
    if [[ $? -ne 0 ]]; then
        echo "CRITICAL: Could not make SQL call to $MARIADB_NAME."
        exit 2
    fi
}

# Verify node is not desynced
DESYNC_OUT=$( run_sql "SHOW VARIABLES LIKE 'wsrep_desync'" "wsrep_desync" )
if [[ "$DESYNC_OUT" != "wsrep_desync	OFF" ]]; then
    echo "WARNING: MariaDB Galera $DESYNC_OUT"
    exit 1
fi

# Verify cluster size is correct
CSIZE_OUT=$( run_sql "SHOW STATUS LIKE 'wsrep_cluster_size'" "wsrep_cluster_size" )
if [[ "$CSIZE_OUT" != "wsrep_cluster_size	3" ]]; then
    echo "WARNING: MariaDB Galera $CSIZE_OUT (should be 3)"
    exit 1
fi

# Verify a SQL query runs without error
QUERY_OUT=$( run_sql "SELECT id FROM search LIMIT 1" )
if [[ "$QUERY_OUT" != id* ]]; then
    echo "WARNING: MariaDB Galera could not be queried."
    exit 1
fi

echo "MariaDB Galera status OK"
exit 0
