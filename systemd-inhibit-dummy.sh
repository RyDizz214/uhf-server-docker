#!/bin/bash
# Dummy systemd-inhibit - skip systemd-inhibit args, pass through rest
# systemd-inhibit uses: --what, --who, --why, --mode
shift_next=false
cmd_started=false
cmd=()

for arg in "$@"; do
    if $shift_next; then
        shift_next=false
        continue
    fi
    
    if ! $cmd_started; then
        case "$arg" in
            --what=*|--who=*|--why=*|--mode=*)
                continue ;;
            --what|--who|--why|--mode)
                shift_next=true
                continue ;;
            -*)
                continue ;;
            *)
                cmd_started=true
                cmd+=("$arg")
                ;;
        esac
    else
        cmd+=("$arg")
    fi
done

exec "${cmd[@]}"
