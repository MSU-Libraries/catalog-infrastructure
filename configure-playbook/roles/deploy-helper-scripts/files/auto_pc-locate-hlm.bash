_pc-locate-hlm()
{
    shopt -s nullglob
    COMPREPLY=()
    CURRENT="${COMP_WORDS[$COMP_CWORD]}"
    HLM_DIR="/mnt/shared/hlm"
    # Change directory to avoid cases where user is currently in an unreadable
    # directory (e.g. just after a sudo) which would cause `find` to throw errors
    cd /

    # TODO -- tab completion doesn't work if flags are passed first
    if [[ $COMP_CWORD -eq 1 ]]; then
        # Get all the environment directory names in HLM_DIR
        readarray -d '' DEPLOY_ENVS < <(find ${HLM_DIR} \
            -maxdepth 1 -mindepth 1 -type d \
            -exec realpath --relative-to ${HLM_DIR} {} \;)

        mapfile -t COMPREPLY < <(compgen -W "${DEPLOY_ENVS[*]}" -- "$CURRENT")
    fi

    # TODO -- adding this makes tab completion stop working
    # (the options display correctly, but can't tab complete to them)
    #COMPREPLY+=(-p --pattern -v --verbose --debug)

    shopt -u nullglob
    return 0
}
complete -F _pc-locate-hlm pc-locate-hlm
