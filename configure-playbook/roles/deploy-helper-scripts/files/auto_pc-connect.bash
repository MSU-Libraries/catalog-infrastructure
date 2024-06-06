_pc-connect()
{
    shopt -s nullglob
    COMPREPLY=()
    CURRENT="${COMP_WORDS[$COMP_CWORD]}"

    # TODO -- tab completion doesn't work if flags are passed first

    if [[ $COMP_CWORD -eq 1 ]]; then
        # Get all of the deployed services
        readarray -d '' SERVICES < <(docker service ls \
            --format "{{.Name}}"
        )
        mapfile -t COMPREPLY < <(compgen -W "${SERVICES[*]}" -- "$CURRENT")

    elif [[ $COMP_CWORD -eq 2 ]]; then
        # return valid node numbers
        NODES=(1 2 3)
        mapfile -t COMPREPLY < <(compgen -W "${NODES[*]}" -- "$CURRENT")
    fi

    # TODO -- adding this makes tab completion stop working
    # (the options display correctly, but can't tab complete to them)
    #COMPREPLY+=(-n --dry-run -c --cmd -d --db -z --zk -v --verbose --debug)

    shopt -u nullglob
    return 0
}
complete -F _pc-connect pc-connect
