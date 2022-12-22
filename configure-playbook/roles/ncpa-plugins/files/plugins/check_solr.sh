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
SOLR_NODE="$2"      # If left blank, will use SOLR_HOST in container
SOLR_NODES=(solr1 solr2 solr3)

# Find local Solr container
CONTAINER=
while read -r CONTAINER; do
    break   # should only be one match anyways
done < <( docker_sudo docker container ls -f "status=running" -f "name=${DEPLOYMENT}-solr_solr." --format "{{ .Names }}" )

if [[ -z "$CONTAINER" ]]; then
    echo "CRITICAL: Cannot find a local Solr container for stack $DEPLOYMENT."
    exit 2
fi

#CLUSTER INFORMATION
#http://SOLR_NODE:8983/solr/admin/collections?action=CLUSTERSTATUS&wt=json

#REPLICAS LIST (is it useful?)
#http://SOLR_NODE:8983/solr/admin/cores?indexInfo=false&wt=json

#http://SOLR_NODE:8983/solr/admin/metrics?nodes=solr1:8983_solr,solr2:8983_solr,solr3:8983_solr&prefix=CONTAINER.fs,org.eclipse.jetty.server.handler.DefaultHandler.get-requests,INDEX.sizeInBytes,SEARCHER.searcher.numDocs,SEARCHER.searcher.deletedDocs,SEARCHER.searcher.warmupTime&wt=json
# Metric fields:
#  nodes : list of nodes to to pull metrics for
#  prefix: list of data to pull
#    CONTAINER.fs: Node file system information (e.g. total/usable space)
#    org.eclipse.jetty.server.handler.DefaultHandler.get-requests: Service performance metrics on GET requests
#    INDEX.sizeInBytes: Per replica, size of replica
#    SEARCHER.searcher.numDocs: Per replica, total number of documents
#    SEARCHER.searcher.deletedDocs: Per replica, number of documents which are marked deleted
#    SEARCHER.searcher.warmupTime: Per replica, warmup time

#MEMORY USE
#http://SOLR_NODE:8983/solr/admin/info/system?nodes=solr1:8983_solr,solr2:8983_solr,solr3:8983_solr&wt=json

run_curl() {
    docker_sudo docker exec -i --env SOLR_NODE="$SOLR_NODE" --env CURL="$1" "${CONTAINER}" bash -c 'export SOLR_NODE="${SOLR_NODE:-$SOLR_HOST}"; curl -s "$(eval echo $CURL)"'
}

# Verify all appropriate collections exist
COLLECTIONS=( authority biblio reserves website )
FOUND_COLLECTIONS=( $( run_curl 'http://$SOLR_NODE:8983/solr/admin/collections?action=LIST&wt=json' | jq -r '.collections|sort|.[]' | paste -sd ' ' - ) )
if [[ "${COLLECTIONS[*]}" != "${FOUND_COLLECTIONS[*]}" ]]; then
    echo "CRITICAL: Incorrect list of collections found: ${FOUND_COLLECTIONS[*]}"
    exit 2
fi

CLUSTER_STATUS=$( run_curl 'http://$SOLR_NODE:8983/solr/admin/collections?action=CLUSTERSTATUS&wt=json' )
for COLLECTION in "${COLLECTIONS[@]}"; do
    # Verify shard health
    SHARD_HEALTH=$( echo "$CLUSTER_STATUS" | jq -r ".cluster.collections.${COLLECTION}.shards.shard1.health" )
    if [[ "$SHARD_HEALTH" != "GREEN" ]]; then
        echo "WARNING: Shard health for ${COLLECTION} is ${SHARD_HEALTH}"
        exit 1
    fi

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
    for NODE in "${SOLR_NODES[@]}"; do
        :
        # TODO verify that there is only a single leader for each collection

        # TODO verify each node has near identical number of records for each collection
    done

    # TODO verify a Solr query runs against each collection without error (in an approriate time)
done

echo "Solr status OK for $DEPLOYMENT"
exit 0
