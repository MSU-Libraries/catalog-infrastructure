#!/bin/bash

#TODO this script could benefit from refactoring

# Prepend sudo to a command if user is not in docker group
docker_sudo() {
    if ! groups | grep -qw docker; then sudo "$@";
    else "$@"; fi
}

if [[ -z "$1" ]]; then
    echo "UNKNOWN: You must provide a deployment name (e.g. catalog-beta) as the first argument."
    exit 3
fi

# Stack deployment name (e.g. catalog-beta, devel-nathan)
DEPLOYMENT="$1"

# Messages to add to the exit output
declare -a MESSAGES

is_main() {
    [[ "$DEPLOYMENT" == "catalog"* ]]
    return $?
}

## Note that the node number here is based on order returned, and NOT the "nodeid" label
NODE_NUM=1
while read -r LINE; do
    NODE_VARNAME=NODE_OUT_${NODE_NUM}
    declare -g ${NODE_VARNAME}="$LINE"
    #if [[ "${!NODE_VARNAME}" =~ ^true ]]; then
    #    declare -g NODE_OUT_SELF="${!NODE_VARNAME}"
    #fi
    (( NODE_NUM += 1 ))
done < <( docker_sudo docker node ls --format '{{ .Self }} {{ .Hostname }} {{ .Status }} {{ .Availability }} {{ .ManagerStatus }} {{ .EngineVersion }}' )

# Node info by index
#   0 = is_self
#   1 = hostname
#   2 = status
#   3 = availability
#   4 = manager_status
#   5 = engine_version
IFS=" " read -r -a NODE_INFO_1 <<< "$NODE_OUT_1"
IFS=" " read -r -a NODE_INFO_2 <<< "$NODE_OUT_2"
IFS=" " read -r -a NODE_INFO_3 <<< "$NODE_OUT_3"
#NODE_INFO_SELF=( $NODE_OUT_SELF )

###############################
## Join all elements of a simple array, optionally be provided delimiter (default: space)
##  $1 -> Name of array to join
##  $2 -> Delimiter
## Output a joined string
join_array() {
    local ARRNAME="$1[*]"
    local DELIM="${2:- }"
    (IFS="$DELIM"; echo "${!ARRNAME}")
}

###############################
## Check if array contains a given value
##  $1 -> Name of array to search
##  $2 -> Value to find
## Returns 0 if an element matches the value to find
array_contains() {
    local ARRNAME="$1[@]"
    local NEEDLE="$2"
    for HAY in "${!ARRNAME}"; do
        if [[ "$NEEDLE" == "$HAY" ]]; then
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
    declare -g -a ALLOWED
    # shellcheck disable=SC2034
    IFS=" " read -r -a ALLOWED <<< "$2"
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
    "${DEPLOYMENT}-catalog"
    "${DEPLOYMENT}-internal"
    "${DEPLOYMENT}-mariadb"
    "${DEPLOYMENT}-solr"
    "${DEPLOYMENT}-monitoring"
    "swarm-cleanup"
    "traefik"
)
FOUND_STACKS=0
while read -r LINE; do
    if array_contains STACK_NAMES "$LINE"; then
        (( FOUND_STACKS += 1 ))
    fi
done < <( docker_sudo docker stack ls --format "{{ .Name }}" )

if [[ "${#STACK_NAMES[@]}" -gt "$FOUND_STACKS" ]]; then
    echo "CRITICAL: Missing one or more Docker stacks (${FOUND_STACKS}/${#STACK_NAMES[@]})."
    exit 2
elif [[ "${#STACK_NAMES}" -lt "$FOUND_STACKS" ]]; then
    echo "UNKNOWN: Excess Docker stacks found! (${FOUND_STACKS}/${#STACK_NAMES[@]}) How?"
    exit 3
fi

# Create list of running containers
declare -a RUNNING_CONTAINERS
while read -r LINE; do
    RUNNING_CONTAINERS+=( "$LINE" )
done < <( docker_sudo docker container ls -f "status=running" -f "name=${DEPLOYMENT}-" --format "{{ .Names }}" )

declare -A EXPECTED_REPLICAS
EXPECTED_REPLICAS=(
    ["${DEPLOYMENT}-internal_health"]=1
    ["${DEPLOYMENT}-catalog_catalog"]=3
    ["${DEPLOYMENT}-catalog_captcha"]=3
    ["${DEPLOYMENT}-catalog_legacylinks"]=3
    ["${DEPLOYMENT}-mariadb_galera"]=3
    ["${DEPLOYMENT}-solr_cron"]=3
    ["${DEPLOYMENT}-solr_proxysolr"]=3
    ["${DEPLOYMENT}-solr_solr"]=3
    ["${DEPLOYMENT}-solr_zk"]=3
    ["${DEPLOYMENT}-monitoring_monitoring"]=3
    ["${DEPLOYMENT}-monitoring_proxymon-${DEPLOYMENT}"]=3
    ["swarm-cleanup_prune-nodes"]=0
    ["traefik_traefik"]=3
)
if is_main; then
    EXPECTED_REPLICAS["${DEPLOYMENT}-catalog_cron"]=1
    EXPECTED_REPLICAS["${DEPLOYMENT}-catalog_build"]=1
else
    EXPECTED_REPLICAS["${DEPLOYMENT}-catalog_croncache"]=3
    EXPECTED_REPLICAS["${DEPLOYMENT}-catalog_mail-${DEPLOYMENT}"]=1
fi

mapfile -t -d' ' EXPECTED_SERVICES < <( echo -n "${!EXPECTED_REPLICAS[@]}" )

# Check if there are unknown containers running with given prefix (e.g. catalog-beta-strangeservice)
for RUNNING in "${RUNNING_CONTAINERS[@]}"; do
    RUN_CONTAINER=$( echo "$RUNNING" | cut -d. -f1 )
    if ! array_contains EXPECTED_SERVICES "$RUN_CONTAINER"; then
        echo "WARNING: Docker container not expected ($RUN_CONTAINER)."
        exit 1
    fi
done

# Check containers have been running for longer than 35 seconds
UNIX_NOW=$( date +%s )
UNIX_M35=$(( UNIX_NOW - 35 ))
for RUNNING in "${RUNNING_CONTAINERS[@]}"; do
    STARTED=$( docker_sudo docker container inspect "$RUNNING" | jq -r .[0].State.StartedAt )
    UNIX_STARTED=$( date -d "$STARTED" +%s )
    if [[ -z "$STARTED" ]]; then
        echo "UNKNOWN: Docker container missing StartedAt value ($RUNNING)."
        exit 3
    elif [[ "$UNIX_STARTED" -ge "$UNIX_M35" ]]; then
        echo "WARNING: Docker container is too young ($RUNNING). Is the health check killing it?."
        exit 1
    fi
done

# Image tags for all replicas in a service should be the same
for SERVICE in "${EXPECTED_SERVICES[@]}"; do
    TARGET_IMAGE=$(docker_sudo docker service inspect "$SERVICE" | jq -r '.[0].Spec.Labels."com.docker.stack.image"')
    if [[ "$TARGET_IMAGE" == "null" ]]; then
        echo "CRITICAL: No service or no image found for service ($SERVICE : $TARGET_IMAGE)"
        exit 2
    fi

    FOUND_REPLICAS=0
    while read -r LINE; do
        (( FOUND_REPLICAS += 1 ))
        if [[ "$LINE" != "$TARGET_IMAGE" && "$TARGET_IMAGE:latest" != "$LINE" ]]; then
            echo "WARNING: Incorrect image tag for ${SERVICE}; expect: ${TARGET_IMAGE##*/}, got: ${LINE##*/}"
            exit 1
        fi
    done < <( docker_sudo docker service ps -f "desired-state=running" --format "{{ .Image }}" "${SERVICE}" )

    if ! is_main && [[ "$SERVICE" == "${DEPLOYMENT}-catalog_catalog" && "$FOUND_REPLICAS" -eq 1 ]]; then
        # We're okay with devel environments being scaled down to 1 catalog replica
        MESSAGES+=("catalog scaled to 1")
        continue
    fi
    if ! is_main && [[ "$SERVICE" == "${DEPLOYMENT}-catalog_captcha" && "$FOUND_REPLICAS" -eq 1 ]]; then
        MESSAGES+=("captcha scaled to 1")
        continue
    fi
    TARGET_REPLICAS="${EXPECTED_REPLICAS[$SERVICE]}"
    if [[ $FOUND_REPLICAS -ne $TARGET_REPLICAS ]]; then
        echo "WARNING: Service $SERVICE has $FOUND_REPLICAS replicas as 'running' (should be $TARGET_REPLICAS)"
        exit 1
    fi
done

# Services' update state should be 'completed' (or 'null' if service never updated)
for SERVICE in "${EXPECTED_SERVICES[@]}"; do
    UPDATE_STATE=$(docker_sudo docker service inspect "${SERVICE}" | jq -r '.[0].UpdateStatus.State')
    if [[ "$UPDATE_STATE" != "completed" && "$UPDATE_STATE" != "null" ]]; then
        echo "WARNING: Service $SERVICE update state is '$UPDATE_STATE' (expected 'completed')"
        exit 1
    fi
done

if [[ "${#MESSAGES[@]}" -gt 0 ]]; then
    MSGSTR=" ($( join_array MESSAGES ';' ))"
fi
echo "Docker status OK for ${DEPLOYMENT}${MSGSTR}"
exit 0
