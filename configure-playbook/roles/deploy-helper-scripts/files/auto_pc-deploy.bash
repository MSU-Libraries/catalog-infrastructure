###############################
## Check if array contains a given value
##  $1 -> Name of array to search
##  $2 -> Value to find
## Returns 0 if an element matches the value to find
_pc-deploy_array_contains() {
    declare -n HAYSTACK="$1"
    declare NEEDLE="$2"
    for HAY in "${HAYSTACK[@]}"; do
        if [[ "$HAY" == "$NEEDLE" ]]; then
            return 0
        fi
    done
    return 1
}

_pc-deploy()
{
    shopt -s nullglob
    COMPREPLY=()
    CURRENT="${COMP_WORDS[$COMP_CWORD]}"
    DEPLOY_BASE="/home/deploy"
    declare DEPLOY_ENV
    declare STACK_CONF
    declare -g -a DEPLOY_ENVS
    declare -g -a ALL_STACKS
    declare -g -a FLAGS
    declare -a completions
    FLAGS=("--debug" "--detach" "-d" "--dry-run" "-n" "--help" "-h" "--prune" "--verbose" "-v")

    # Get all the environment directory names in DEPLOY_BASE
    readarray -d '' DEPLOY_ENVS < <(find ${DEPLOY_BASE} \
        -maxdepth 1 -mindepth 1 '(' -name "catprod-*" -o \
        -name "devel-*" -o -name "core-stacks" -o -name "review-*" ')' \
        -exec realpath -z --relative-to ${DEPLOY_BASE} {} \; 2>/dev/null)

    for ((i=1; i<${#COMP_WORDS[@]}; i++)); do
        word="${COMP_WORDS[i]}"
        if _pc-deploy_array_contains FLAGS "$word"; then
            continue
        else
            if [[ -z $DEPLOY_ENV ]]; then
                if _pc-deploy_array_contains DEPLOY_ENVS "$word"; then
                    DEPLOY_ENV="$word"
                fi
                continue
            fi

            if [[ ${#ALL_STACKS[@]} -eq 0 ]]; then
                # Finds all compose files in the environment directory selected
                readarray -d '' STACK_CONFS < \
                    <(find ${DEPLOY_BASE}/"${DEPLOY_ENV}"/docker-compose.*.yml \
                    -exec realpath -z --relative-to ${DEPLOY_BASE}/"${DEPLOY_ENV}" {} \; 2>/dev/null)

                # Finds just the names of the stacks (i.e solr-cloud or vufind)
                readarray -d '' STACKS < \
                    <(find ${DEPLOY_BASE}/"${DEPLOY_ENV}"/docker-compose.*.yml \
                    -exec sh -c 'T="${0#*.}"; printf "%s\0" "${T%.yml}";' {}  \; 2>/dev/null)

                ALL_STACKS=("${STACK_CONFS[@]}" "${STACKS[@]}")
            fi

            if [[ -z $STACK_CONF ]]; then
                if _pc-deploy_array_contains ALL_STACKS "$word"; then
                    STACK_CONF="$word"
                fi
                continue
            fi
        fi
    done

    completions=()
    if [[ -z $DEPLOY_ENV ]]; then
        completions+=("${DEPLOY_ENVS[@]}")
    elif [[ -z $STACK_CONF ]]; then
        completions+=("${ALL_STACKS[@]}")
    fi
    completions+=("${FLAGS[@]}")
    mapfile -t COMPREPLY < <(compgen -W "${completions[*]}" -- "$CURRENT")

    shopt -u nullglob
    return 0
}
complete -F _pc-deploy pc-deploy
