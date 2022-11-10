#!/bin/bash

#TODO this script could benefit from refactoring

## Note that the node number here is based on order returned, and NOT the "nodeid" label
NODE_NUM=1
while read -r LINE; do
    NODE_VARNAME=NODE_OUT_${NODE_NUM}
    declare -g ${NODE_VARNAME}="$LINE"
    #if [[ "${!NODE_VARNAME}" =~ ^true ]]; then
    #    declare -g NODE_OUT_SELF="${!NODE_VARNAME}"
    #fi
    (( NODE_NUM += 1 ))
done < <( docker node ls --format '{{ .Self }} {{ .Hostname }} {{ .Status }} {{ .Availability }} {{ .ManagerStatus }} {{ .EngineVersion }}' )

# Node info by index
#   0 = is_self
#   1 = hostname
#   2 = status
#   3 = availability
#   4 = manager_status
#   5 = engine_version
NODE_INFO_1=( $NODE_OUT_1 )
NODE_INFO_2=( $NODE_OUT_2 )
NODE_INFO_3=( $NODE_OUT_3 )
#NODE_INFO_SELF=( $NODE_OUT_SELF )

###############################
## Check if array contains a given value
##  $1 -> Name of array to search
##  $2 -> Value to find
## Returns 0 if an element matches the value to find
array_contains() {
    local ARRNAME=$1[@]
    local HAYSTACK=( ${!ARRNAME} )
    local NEEDLE="$2"
    for VAL in "${HAYSTACK[@]}"; do
        if [[ "$NEEDLE" == "$VAL" ]]; then
            return 0
        fi
    done
    return 1
}

verify_nodes() {
    # $1 - Node info index to check
    # $2 - Values (string, space delimited) which are allowed
    # $3 - Description of check type
    # $4 - Expected match count
    IDX=$1
    declare -g -a ALLOWED=( $2 )
    CHECK_TYPE="$3"
    COUNT_OKAY=${4:-3}     # default to 3 matches needed
    COUNT_CRITICAL=$(( COUNT_OKAY > 2 ? COUNT_OKAY - 2 : COUNT_OKAY - 1 ))
    COUNT_WARNING=$(( COUNT_OKAY > 2 ? COUNT_OKAY - 1 : COUNT_OKAY ))
    OKAY_NODES=0
    if array_contains ALLOWED "${NODE_INFO_1[$IDX]}"; then
        (( OKAY_NODES += 1 ))
    fi
    if array_contains ALLOWED "${NODE_INFO_2[$IDX]}"; then
        (( OKAY_NODES += 1 ))
    fi
    if array_contains ALLOWED "${NODE_INFO_3[$IDX]}"; then
        (( OKAY_NODES += 1 ))
    fi
    if [[ "$OKAY_NODES" -eq "$COUNT_OKAY" ]]; then
        return 0
    elif [[ "$OKAY_NODES" -gt "$COUNT_OKAY" ]]; then
        echo "WARNING: Docker $CHECK_TYPE; too many nodes = $OKAY_NODES"
        exit 1
    elif [[ "$OKAY_NODES" -le "$COUNT_CRITICAL" ]]; then
        echo "CRITIAL: Docker $CHECK_TYPE; okay nodes = $OKAY_NODES"
        exit 2
    elif [[ "$OKAY_NODES" -le "$COUNT_WARNING" ]]; then
        echo "WARNING: Docker $CHECK_TYPE; okay nodes = $OKAY_NODES"
        exit 1
    fi
    echo "UNKNOWN: Docker $CHECK_TYPE"
    exit 3
}

# Check docker cluster state (appropriate node count, all nodes are managers, one is leader)
verify_nodes 4 "Leader Reachable" "nodes are managers"
verify_nodes 4 "Leader" "has a leader" 1
verify_nodes 2 "Ready" "status"
verify_nodes 3 "Active" "availability"

# Check appropriate stacks are deployed (both shared containers and prod containers)
STACK_NAMES=(
    catalog-beta-catalog
    catalog-beta-internal
    catalog-beta-mariadb
    catalog-beta-solr
    swarm-cron
    traefik
)
FOUND_STACKS=0
while read -r LINE; do
    if array_contains STACK_NAMES "$LINE"; then
        (( FOUND_STACKS += 1 ))
    fi
done < <( docker stack ls --format "{{ .Name }}" )

if [[ "${#STACK_NAMES[@]}" -gt "$FOUND_STACKS" ]]; then
    echo "CRITICAL: Missing one or more production Docker stacks (${FOUND_STACKS}/${#STACK_NAMES[@]})."
    exit 2
elif [[ "${#STACK_NAMES}" -lt "$FOUND_STACKS" ]]; then
    echo "UNKNOWN: Excess production Docker stacks found! (${FOUND_STACKS}/${#STACK_NAMES[@]}) How?"
    exit 3
fi

# Check appropriate service replicas are running
# TODO can improve this by separating sevice name and expected replica count and checking/reporting specifics
SERVICES=(
    "catalog-beta-catalog_catalog 3/3 (max 1 per node)"
    "catalog-beta-catalog_cron 1/1"
    "catalog-beta-internal_health 1/1"
    "catalog-beta-mariadb_galera 3/3 (max 1 per node)"
    "catalog-beta-solr_cron 3/3 (max 1 per node)"
    "catalog-beta-solr_solr 3/3 (max 1 per node)"
    "catalog-beta-solr_zk 3/3 (max 1 per node)"
    "swarm-cron_swarm-cronjob 1/1"
    "traefik_traefik 1/1 (max 1 per node)"
)
declare -a FOUND_SERVICES
while read -r LINE; do
    FOUND_SERVICES+=( "${LINE// /~}" )  # hacky fix to avoid spaces
done < <( docker service ls --format "{{ .Name }} {{ .Replicas }}" )

for SERVICE in "${SERVICES[@]}"; do
    SERVICE="${SERVICE// /~}"           # hacky fix to avoid spaces
    if ! array_contains FOUND_SERVICES "$SERVICE"; then
        SSPLIT=( ${SERVICE//~/ } )
        echo "WARNING: Docker service ${SSPLIT[0]} not at expected replica count."
        exit 1
    fi
done

# Create list of running containers
declare -a RUNNING_CONTAINERS
while read -r LINE; do
    RUNNING_CONTAINERS+=( "$LINE" )
done < <( docker container ls -f "status=running" -f "name=catalog-beta-" --format "{{ .Names }}" )

EXPECTED_CONTAINERS=(
    catalog-beta-catalog_catalog
    catalog-beta-catalog_cron
    catalog-beta-internal_health
    catalog-beta-mariadb_galera
    catalog-beta-solr_cron
    catalog-beta-solr_solr
    catalog-beta-solr_zk
)

# Check if there are unknown containers running with given prefix (e.g. catalog-beta-strangeservice)
for RUNNING in "${RUNNING_CONTAINERS[@]}"; do
    RUN_CONTAINER=$( echo "$RUNNING" | cut -d. -f1 )
    if ! array_contains EXPECTED_CONTAINERS "$RUN_CONTAINER"; then
        echo "WARNING: Docker container not expected ($RUN_CONTAINER)."
        exit 1
    fi
done

# Check containers have been running for longer than 35 seconds
UNIX_NOW=$( date +%s )
UNIX_M35=$(( UNIX_NOW - 35 ))
for RUNNING in "${RUNNING_CONTAINERS[@]}"; do
    STARTED=$( docker container inspect "$RUNNING" | jq -r .[0].State.StartedAt )
    UNIX_STARTED=$( date -d "$STARTED" +%s )
    if [[ -z "$STARTED" ]]; then
        echo "UNKNOWN: Docker container missing StartedAt value ($RUNNING)."
        exit 3
    elif [[ "$UNIX_STARTED" -ge "$UNIX_M35" ]]; then
        echo "WARNING: Docker container is too young ($RUNNING). Is the health check killing it?."
        exit 1
    fi
done

echo "Docker status OK"
exit 0
