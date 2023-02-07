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
ZK_HOSTS="$2"      # If left blank, will use SOLR_ZK_HOSTS in container

# Find local container
ZK_CONTAINER=
while read -r ZK_CONTAINER; do
    break   # should only be one match anyways
done < <( docker_sudo docker container ls -f "status=running" -f "name=${DEPLOYMENT}-solr_zk." --format "{{ .Names }}" )

if [[ -z "$ZK_CONTAINER" ]]; then
    echo "CRITICAL: Cannot find a local Zookeeper container for stack $DEPLOYMENT."
    exit 2
fi

SOLR_CONTAINER=
while read -r SOLR_CONTAINER; do
    break   # should only be one match anyways
done < <( docker_sudo docker container ls -f "status=running" -f "name=${DEPLOYMENT}-solr_solr." --format "{{ .Names }}" )

if [[ -z "$SOLR_CONTAINER" ]]; then
    echo "CRITICAL: Cannot find a local Solr container for stack $DEPLOYMENT."
    exit 2
fi

SOLR_ZK_HOSTS=$( docker_sudo docker exec -i "${SOLR_CONTAINER}" bash -c 'echo "$SOLR_ZK_HOSTS"' )
NODE_ZK_HOST=$( docker_sudo docker exec -i "${ZK_CONTAINER}" bash -c 'echo "$HOSTNAME"' )
ZK_HOSTS="${SOLR_ZK_HOSTS:-$ZK_HOSTS}"

# Send a command to Zookeeper and output the response
#  $1 => The command to send
#  $2 => The zookeeper host (e.g. "zk2:2181") to connect to. Optional, if not specified will container: ${HOSTNAME}:2181
run_zk_cmd() {
    docker_sudo docker exec -i --env ZK_HOSTS="${2:-$NODE_ZK_HOST:2181}" --env ARG="$1" "${ZK_CONTAINER}" bash -c 'export ZK_HOST=${ZK_HOSTS//,*}; echo "${ARG}" | nc ${ZK_HOST//:/ }'
}

# Get/cat a JSON file from Zookeeper
#  $1 => The full zk path to the file
#  $2 => The zookeeper host (e.g. "zk2:2181") to connect to. Optional, if not specified will container: ${HOSTNAME}:2181
run_zkshell_cat() {
    docker_sudo docker exec -i --env ZK_HOSTS="${2:-$NODE_ZK_HOST:2181}" --env ARG="$1" "${ZK_CONTAINER}" bash -c 'zk-shell "$ZK_HOSTS" --run-once "json_cat ${ARG}"'
}

# Verify node's Zookeeper instance is okay
RUOK=$( run_zk_cmd "ruok" )
if [[ "${RUOK}" != "imok" ]]; then
    echo "CRITICAL: Zookeeper on node (${NODE_ZK_HOST}) is not okay"
    exit 2
fi

# Verify zookeeper cluster has 1 leader and 2 non-leaders
ZK_HOST_ARR=( ${ZK_HOSTS//,/ } )
ZK_LEADER=()
ZK_FOLLOW=()
for ZKH in "${ZK_HOST_ARR[@]}"; do
    ZK_MODE=$( run_zk_cmd "stat" "${ZKH}" | grep "^Mode:" )
    if [[ "$ZK_MODE" == "Mode: leader" ]]; then
        ZK_LEADER+=("$ZKH")
    elif [[ "$ZK_MODE" == "Mode: follower" ]]; then
        ZK_FOLLOW+=("$ZKH")
    fi
done
if [[ "${#ZK_LEADER[@]}" -ne 1 ]]; then
    echo "CRITICAL: Zookeeper (${NODE_ZK_HOST}) cannot find the leader"
    exit 2
elif [[ "${#ZK_FOLLOW[@]}" -ne 2 ]]; then
    echo "WARNING: Zookeeper (${NODE_ZK_HOST}) found incorrect number of followers (${#ZK_FOLLOW})"
    exit 2
fi

COLLECTIONS=( authority biblio reserves website )
for COLL in "${COLLECTIONS[@]}"; do
    ZK_HOST_ARR=( ${ZK_HOSTS//,/ } )
    COLL_MD5=
    for ZKH in "${ZK_HOST_ARR[@]}"; do
        COLL_STATE=$( run_zkshell_cat "/solr/collections/${COLL}/state.json" "$ZKH" )
        # Verify solr collections' state.json are identical from each node, if possible
        MD5=($( echo "$COLL_STATE" | md5sum ))
        if [[ -n "$COLL_MD5" && "$MD5" != "$COLL_MD5" ]]; then
            echo "CRITICAL: Zookeeper (${ZKH//:*}) for ${COLL} status.json out of sync from other node(s)"
            exit 2
        fi
        COLL_MD5="$MD5"
    done

    for ZKH in "${ZK_HOST_ARR[@]}"; do
        # Verify solr collections' state.json indicate 1 leader and 2 non-leaders
        SHARDS=( $(echo "$COLL_STATE" | jq -r ".${COLL}.shards | keys | join (\" \")") )
        for SHARD in "${SHARDS[@]}"; do
            REPLICA_CNT=$(echo "$COLL_STATE" | jq -r ".${COLL}.shards.${SHARD}.replicas | length" )
            LEADER=$(echo "$COLL_STATE" | jq -r ".${COLL}.shards.${SHARD}.replicas[] | select(.leader == \"true\").leader")
            if [[ "${REPLICA_CNT}" -ne 3 ]]; then
                echo "WARNING: Zookeeper (${ZKH//:*}) found ${REPLICA_CNT} replicas for ${COLL} status.json"
                exit 1
            elif [[ "$LEADER" != "true" ]]; then
                echo "CRITICAL: Zookeeper (${ZKH//:*}) has incorrect replica leader count in ${COLL} status.json"
                exit 2
            fi
        done
    done
done

echo "Zookeeper status OK for $DEPLOYMENT"
exit 0
