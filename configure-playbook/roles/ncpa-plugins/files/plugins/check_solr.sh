#!/bin/bash

# shellcheck disable=SC2016,SC2207

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
SOLR_NODE="$2"      # If left blank, will use SOLR_HOST in container
ZK_HOSTS="$3"      # If left blank, will use SOLR_ZK_HOSTS in container
SOLR_NODES=(solr1 solr2 solr3)

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

# shellcheck disable=SC2016
SOLR_ZK_HOSTS=$( docker_sudo docker exec -i "${SOLR_CONTAINER}" bash -c 'echo "$SOLR_ZK_HOSTS"' )
# shellcheck disable=SC2016
NODE_ZK_HOST=$( docker_sudo docker exec -i "${ZK_CONTAINER}" bash -c 'echo "$HOSTNAME"' )
ZK_HOSTS="${SOLR_ZK_HOSTS:-$ZK_HOSTS}"

# PERFORMANCE
#TODO warn if load become excessive or query performance slows
#http://SOLR_NODE:8983/solr/admin/metrics?nodes=SOLR_NODE:8983_solr&prefix=org.eclipse.jetty.server.handler.DefaultHandler.get-requests&wt=json

# MEMORY USE
#TODO warn if Solr memory use approaches Java max allotment
#http://SOLR_NODE:8983/solr/admin/info/system?nodes=SOLR_NODE:8983_solr&wt=json

run_curl() {
    docker_sudo docker exec -i --env SOLR_NODE="$SOLR_NODE" --env CURL="$1" "${SOLR_CONTAINER}" bash -c 'export SOLR_NODE="${SOLR_NODE:-$SOLR_HOST}"; curl -s "$(eval echo $CURL)"'
}

run_getent_hosts() {
    docker_sudo docker exec -i --env HOSTCHECK="$1" "${SOLR_CONTAINER}" bash -c 'getent hosts "$(eval echo $HOSTCHECK)" > /dev/null'
}

# Get/cat a JSON file from Zookeeper
#  $1 => The full zk path to the file
#  $2 => The zookeeper host (e.g. "zk2:2181") to connect to. Optional, if not specified will container: ${HOSTNAME}:2181
run_zkshell_cat() {
    docker_sudo docker exec -i --env ZK_HOSTS="${2:-$NODE_ZK_HOST:2181}" --env ARG="$1" "${ZK_CONTAINER}" bash -c 'zk-shell "$ZK_HOSTS" --run-once "json_cat ${ARG}"'
}

# Verify each container can resolve the hostname of all cluster containers
for NODE in "${SOLR_NODES[@]}"; do
    if ! run_getent_hosts "$NODE"; then
        echo "WARNING: Could not resolve host $NODE from within solr container."
        exit 1
    fi
done

# Map collections to aliases
FIND_COLLECTIONS=( authority biblio1 biblio2 reserves website )

# Verify all appropriate collections exist
FOUND_COLLECTIONS=( $( run_curl "http://\${SOLR_NODE}:8983/solr/admin/collections?action=LIST\&wt=json" | jq -r '.collections|sort|.[]' | paste -sd ' ' - ) )
if [[ "${FIND_COLLECTIONS[*]}" != "${FOUND_COLLECTIONS[*]}" ]]; then
    echo "CRITICAL: Incorrect list of collections found: ${FOUND_COLLECTIONS[*]}. Expected: ${FIND_COLLECTIONS[*]}"
    exit 2
fi

NODE_METRICS=$( run_curl "http://\${SOLR_NODE}:8983/solr/admin/metrics?nodes=solr1:8983_solr,solr2:8983_solr,solr3:8983_solr\&prefix=SEARCHER.searcher.numDocs,SEARCHER.searcher.deletedDocs\&wt=json" )
CLUSTER_STATUS=$( run_curl "http://\${SOLR_NODE}:8983/solr/admin/collections?action=CLUSTERSTATUS\&wt=json" )
for COLLECTION in "${FIND_COLLECTIONS[@]}"; do
    # Verify each node has one (and only one) replica for each collection
    REP_IDX=0
    REP_PREV=
    while read -r REP_HOST; do
        if [[ "$REP_PREV" == "$REP_HOST" ]]; then
            echo "CRITICAL: Found more than one replica for $COLLECTION on $REP_HOST"
            exit 1
        fi
        if [[ "$REP_IDX" -ge 3 ]]; then
            echo "CRITICAL: Found extra replica for $COLLECTION on $REP_HOST"
            exit 2
        fi
        if [[ "${SOLR_NODES[$REP_IDX]}" != "$REP_HOST" ]]; then
            echo "WARNING: Missing expected $COLLECTION replica on ${SOLR_NODES[$REP_IDX]}"
            exit 1
        fi
        (( REP_IDX += 1 ))
        REP_PREV="$REP_HOST"
    done < <( echo "$CLUSTER_STATUS" | jq -r ".cluster.collections.${COLLECTION}.shards.shard1.replicas[].node_name" | cut -f1 -d':' | sort )

    if [[ "$REP_IDX" -ne 3 ]]; then
        echo "CRITICAL: Missing replica(s) for $COLLECTION (found ${REP_IDX})"
        exit 2
    fi

    # Run from each node's perspective to ensure consistency
    LEADERS=()
    RCOUNTS=()
    for NODE in "${SOLR_NODES[@]}"; do
        NODE_CLUSTER_STATUS=$( run_curl "http://${NODE}:8983/solr/admin/collections?action=CLUSTERSTATUS\&wt=json" )

        NODE_LEADERS=( $( echo "$NODE_CLUSTER_STATUS" | jq -r "[.cluster.collections.${COLLECTION}.shards.shard1.replicas[]]|sort_by(.node_name)[].leader" | paste -sd ' ' - ) )
        for IDX in "${!NODE_LEADERS[@]}"; do
            if [[ "${NODE_LEADERS[$IDX]}" == "true" ]]; then
                LEADERS+=("${SOLR_NODES[$IDX]}")
            fi
        done

        NODE_RCOUNT=$( echo "$NODE_METRICS" | jq -r "to_entries[]|select(.key|startswith(\"${NODE}:\")).value.metrics|to_entries[]|select(.key|startswith(\"solr.core.${COLLECTION}.\")).value.\"SEARCHER.searcher.numDocs\"" )
        RCOUNTS+=("$NODE_RCOUNT")
    done

    # Verify that there is only a single leader for each collection
    if [[ "${#LEADERS[@]}" -ne 3 ]]; then
        echo "CRITICAL: For collection ${COLLECTION}, 3 nodes found ${#LEADERS[@]} leaders: ${LEADERS[*]}"
        exit 2
    fi
    mapfile -t LEADER_MATCH < <( printf "%s\n" "${LEADERS[@]}" | sort -u )
    if [[ "${#LEADER_MATCH[@]}" -ne 1 ]]; then
        echo "CRITICAL: For collection ${COLLECTION}, multiple leaders found: ${LEADER_MATCH[*]}"
        exit 2
    fi

    # Verify shard health
    SHARD_HEALTH=$( echo "$CLUSTER_STATUS" | jq -r ".cluster.collections.${COLLECTION}.shards.shard1.health" )
    if [[ "$SHARD_HEALTH" != "GREEN" ]]; then
        echo "WARNING: Shard health for ${COLLECTION} is ${SHARD_HEALTH}"
        exit 1
    fi

    # Verify one replica per node and they are active
    SHARDS=( $(echo "$CLUSTER_STATUS" | jq -r ".cluster.collections.${COLLECTION}.shards | keys | join (\" \")") )
    for SHARD in "${SHARDS[@]}"; do
        ACTIVE_REPLICAS=( $(echo "$CLUSTER_STATUS" | jq -r ".cluster.collections.${COLLECTION}.shards.${SHARD}.replicas[] | select(.state == \"active\") | .node_name | sub(\":8983_solr\";\"\")" | sort) )
        if [[ -z "${ACTIVE_REPLICAS[*]}" ]]; then
            echo "CRITICAL: No active replicas for ${COLLECTION}.${SHARD}"
            exit 1
        elif [[ "${ACTIVE_REPLICAS[*]}" != "${SOLR_NODES[*]}" ]]; then
            echo "WARNING: Active replicas for ${COLLECTION}.${SHARD} is '${ACTIVE_REPLICAS[*]}' (should be '${SOLR_NODES[*]}')"
            exit 1
        fi
    done

    # Verify each node has (near?) identical number of records for each collection
    mapfile -t RCOUNT_MATCH < <( printf "%s\n" "${RCOUNTS[@]}" | sort -u )
    if [[ "${#RCOUNT_MATCH[@]}" -ne 1 ]]; then
        echo "WARNING: For collection ${COLLECTION}, replica doc counts do not match: ${RCOUNT_MATCH[*]}"
        exit 1
    fi

    # Verify a Solr query runs against the collection without error
    QUERY_RESP=$( run_curl "http://\${SOLR_NODE}:8983/solr/${COLLECTION}/select?q=*:*\&rows=1\&wt=json" )
    QUERY_STATUS=$( echo "$QUERY_RESP" | jq -r '.responseHeader.status' )
    if [[ "$QUERY_STATUS" -ne 0 ]]; then
        echo "CRITICAL: Unable to query collection ${COLLECTION}; response status of ${QUERY_STATUS}"
        exit 2
    fi

    # General health check against collection
    COLL_HEALTH=$( echo "$CLUSTER_STATUS" | jq -r ".cluster.collections.${COLLECTION}.health" )
    if [[ "$COLL_HEALTH" != "GREEN" ]]; then
        echo "WARNING: Collection health for ${COLLECTION} is ${COLL_HEALTH}"
        exit 1
    fi
done

echo "Solr status OK for $DEPLOYMENT"
exit 0
