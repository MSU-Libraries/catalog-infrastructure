_pc-deploy()
{
    shopt -s nullglob
    COMPREPLY=()
    CURRENT="${COMP_WORDS[$COMP_CWORD]}"
    PREV="${COMP_WORDS[$COMP_CWORD-1]}"
    DEPLOY_DIR="/home/deploy"
    # Change directory to avoid cases where user is currently in an unreadable
    # directory (e.g. just after a sudo) which would cause `find` to throw errors
    cd /

    if [[ $COMP_CWORD -eq 1 ]]; then
        # Get all the environment directory names in DEPLOY_DIR
        readarray -d '' DEPLOY_ENVS < <(find ${DEPLOY_DIR} \
            -maxdepth 1 -mindepth 1 '(' -name "catalog-*" -o \
            -name "devel-*" -o -name "core-stacks" -o -name "review-*" ')' \
            -exec realpath --relative-to ${DEPLOY_DIR} {} \;)
        
        mapfile -t COMPREPLY < <(compgen -W "${DEPLOY_ENVS[*]}" -- "$CURRENT")
    
    elif [[ $COMP_CWORD -eq 2 ]]; then
        # Finds all compose files in the environment directory selected
        readarray -d '' STACK_CONFS < <(find ${DEPLOY_DIR}/"${PREV}"/docker-compose.*.yml \
            -exec realpath --relative-to ${DEPLOY_DIR}/"${PREV}" {} \;)
        
        # Finds just the names of the stacks (i.e solr-cloud or vufind)
        readarray -d '' STACKS < <(find ${DEPLOY_DIR}/"${PREV}"/docker-compose.*.yml \
            -exec sh -c 'T="${0#*.}"; echo "${T%.yml}";' {}  \;)
       
        # Combine the two arrays for the final output of suggestions
        ALL=("${STACK_CONFS[@]}" "${STACKS[@]}")
        mapfile -t COMPREPLY < <(compgen -W "${ALL[*]}" -- "$CURRENT")
    fi
    shopt -u nullglob
    return 0
}
complete -F _pc-deploy pc-deploy
