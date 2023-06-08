#!/bin/bash

# Prepend sudo to a command if user is not in docker group
docker_sudo() {
    if ! groups | grep -qw docker; then sudo "$@";
    else "$@"; fi
}

# Prepend sudo to a command if user is not root
root_sudo() {
    if [[ "$EUID" -ne 0 ]]; then sudo "$@";
    else "$@"; fi
}

if [[ -z "$1" ]]; then
    echo "UNKNOWN: You must provide a deployment name (e.g. catalog-beta) as the first argument."
    exit 3
fi

DEPLOYMENT="$1"
MARIADB_USER="${2:-root}"
MARIADB_PASS="${3:-12345}"
GALERA_NODES=(galera1 galera2 galera3)

# Find local MariaDB container
MARIADB_NAME=
while read -r LINE; do
    if [[ "$LINE" == "${DEPLOYMENT}-mariadb_galera"* ]]; then
        MARIADB_NAME="$LINE"
        break;
    fi
done < <( docker_sudo docker container ls -f "status=running" -f "name=${DEPLOYMENT}-" --format "{{ .Names }}" )

if [[ -z "$MARIADB_NAME" ]]; then
    echo "CRITICAL: Cannot find MariaDB container for given stack."
    exit 2
fi

# SQL single line query match
run_sql() {
    FILTER="${2}"
    docker_sudo docker exec -i ${MARIADB_NAME} mysql -u${MARIADB_USER} -p${MARIADB_PASS} vufind -e "$1" | grep "$FILTER"
    if [[ $? -ne 0 ]]; then
        echo "CRITICAL: Could not make SQL call to $MARIADB_NAME."
        exit 2
    fi
}

# SQL full query response
run_full_sql() {
    QUERY="$1"
    declare -g ROW_CNT=0
    declare -g -a ROW_$ROW_CNT=
    while read -r -a ROW_$ROW_CNT; do
        (( ROW_CNT+=1 ))
        declare -g -a ROW_$ROW_CNT
    done < <( docker_sudo docker exec -i "${MARIADB_NAME}" mysql -u"${MARIADB_USER}" -p"${MARIADB_PASS}" vufind --silent -e "$QUERY" )
    if [[ "$ROW_CNT" -eq 0 ]]; then
        echo "CRITICAL: No response from $MARIADB_NAME query >> $QUERY"
        exit 2
    fi
    return $ROW_CNT
}

run_getent_hosts() {
    docker_sudo docker exec -i --env HOSTCHECK="$1" "${MARIADB_NAME}" bash -c 'getent hosts "$(eval echo $HOSTCHECK)" > /dev/null'
}

# Verify each container can resolve the hostname of all cluster containers
for NODE in "${GALERA_NODES[@]}"; do
    if ! run_getent_hosts "$NODE"; then
        echo "WARNING: Could not resolve host $NODE from within galera container."
        exit 1
    fi
done

# Verify node and cluster status
run_full_sql "SHOW WSREP_STATUS"
# Row indices => 0:Node_Index,1:Node_Status,2:Cluster_Status,3:Cluster_Size
if [[ "${ROW_0[1]}" != "synced" ]]; then
    echo "WARNING: Node not synced (status: ${ROW_0[1]})"
    exit 1
fi
if [[ "${ROW_0[2]}" != "primary" ]]; then
    echo "WARNING: Cluster not primary (status: ${ROW_0[2]})"
    exit 1
fi

run_full_sql "SHOW WSREP_MEMBERSHIP"
# Row indices => 0:Index,1:Uuid,2:Name,3:Address
ROW_CNT="$?"
declare -a FOUND_NODES=()
declare -a FOUND_SORTED=()
for ((IDX=0; IDX<ROW_CNT; IDX++)); do
    NNVAR="ROW_$IDX[2]"
    FOUND_NODES+=("${!NNVAR}")
done
OIFS="$IFS";
IFS=$'\n' FOUND_SORTED=($(sort <<<"${FOUND_NODES[*]}"))
IFS="$OIFS"
if [[ "${GALERA_NODES[*]}" != "${FOUND_SORTED[*]}" ]]; then
    echo "WARNING: Cluster members incorrect >> ${FOUND_SORTED[*]}"
    exit 1
fi
if [[ "$ROW_CNT" -ne 3 ]]; then
    echo "WARNING: Bad member count ($ROW_CNT) from WSREP_MEMBERSHIP."
    exit 1
fi

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
QUERY_OUT=$( run_sql "SHOW CREATE TABLE user" )
if [[ "$QUERY_OUT" != Table* ]]; then
    echo "WARNING: Could not query create data from user table."
    exit 1
fi

# Check for unsafe shutdown
root_sudo /usr/bin/test -f /var/lib/docker/volumes/${DEPLOYMENT}-mariadb_db-bitnami/_data/mariadb/node_shutdown_unsafely
if [[ "$?" -eq 0 ]]; then
    echo "WARNING: Node had unsafe shutdown flag file (/bitnami/mariadb/node_shutdown_unsafely)"
    exit 1
fi

echo "MariaDB Galera status OK for $DEPLOYMENT"
exit 0
