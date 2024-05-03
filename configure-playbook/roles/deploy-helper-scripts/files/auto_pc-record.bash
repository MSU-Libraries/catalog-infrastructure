#!/bin/bash
AVAILABLE_ACTIONS="(delete)"
VALID_PREFIX="(hlm|folio)"
VALID_TARGET="(Solr)"
AVAILABLE_FLAGS=(
                "-h"
                "--help"
                "-n"
                "--dry-run"
                "-t"
                "--target"
                "-v"
                "-vv"
                "-vvv"
                "--verbose"
                "-d"
                "--debug"
                "-q"
                "--quiet"
                "-y"
                "--yes"
                "-i"
                "--input"
                "--prefix"
            )
AVAILABLE_STACKS_PATH="/mnt/shared/local/"
AVAILABLE_STACKS=()
for file in "${AVAILABLE_STACKS_PATH}"/*; do
    [[ -d "$file" ]] || continue
    AVAILABLE_STACKS+=("$(basename "${file}")")
done

is_stack_provided() {
    # We are already in the container
    if [[ -n "$STACK_NAME" ]]; then
        return 0
    fi
    for command_part in "${COMP_WORDS[@]}"; do
        for stack in "${AVAILABLE_STACKS[@]}"; do
            if [[ "${command_part}" == "${stack}" ]]; then
              return 0
            fi
        done
    done

    return 1
}

is_action_provided() {
    local tmp
    tmp="${AVAILABLE_ACTIONS//[()]/}"
    for command_part in "${COMP_WORDS[@]}"; do
        for available_action in ${tmp//|/ }; do
            if [[ "${command_part}" == "${available_action}" ]]; then
              return 0
            fi
        done
    done

    return 1
}

get_unused_flags() {
    local used_flag unused_flags tmp_used_flag
    unused_flags=()

    for flag in "${AVAILABLE_FLAGS[@]}"; do
        tmp_used_flag=false
        for used_flag in "${COMP_WORDS[@]}"; do
            if [[ "${flag}" == "${used_flag}" ]]; then
                tmp_used_flag=true
                break
            fi
        done
        if ! ${tmp_used_flag}; then
            unused_flags+=("${flag}")
        fi
    done

    echo "${unused_flags[@]}"
}

_usage_completion() {
    local current_word previous_word
    current_word="${COMP_WORDS[COMP_CWORD]}"
    if [[ $COMP_CWORD -eq 0 ]]; then
        previous_word=""
    else
        previous_word="${COMP_WORDS[COMP_CWORD-1]}"
    fi

    case "${previous_word}" in
        -t|--target)
            tmp="${VALID_TARGET//[()]/}"
            # shellcheck disable=SC2207
            COMPREPLY=($(compgen -W "${tmp//|/ }" -- "$current_word"))
            return 0
            ;;
        -i|--input)
            # shellcheck disable=SC2207
            COMPREPLY=($(compgen -f -- "$current_word"))
            return 0
            ;;
        --prefix)
            tmp="${VALID_PREFIX//[()]/}"
            # shellcheck disable=SC2207
            COMPREPLY=($(compgen -W "${tmp//|/ }" -- "$current_word"))
            return 0
            ;;
    esac

    # Check if the complete command contains a stack name
    if [[ ! ${current_word} == -* ]] && ! is_action_provided; then
        local tmp
        tmp="${AVAILABLE_ACTIONS//[()]/}"
        # shellcheck disable=SC2207
        COMPREPLY=($(compgen -W "${tmp//|/ }" -- "$current_word"))
        return 0
    fi
    if [[ ! ${current_word} == -* ]] && ! is_stack_provided; then
        # shellcheck disable=SC2207
        COMPREPLY=($(compgen -W "${AVAILABLE_STACKS[*]}" -- "$current_word"))
        return 0
    fi
    # shellcheck disable=SC2207
    COMPREPLY=($(compgen -W "$(get_unused_flags)" -- "$current_word"))
    return 0
}

complete -F _usage_completion -o default pc-record
