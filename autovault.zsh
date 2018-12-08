#!/usr/bin/env zsh
CWD="$(cd "$(dirname "${(%):-%x}")";pwd -P)"

ask() {
    if [[ ${1} =~ "'([^']+)' (password|MFA token):" ]]; then
        vault=${match[1]}

        #
        # Inject requested credential from 1password
        case "${match[2]}" in
            password ) echo $(1pass -p "cli:vaulted:${vault}" password) ;;
            *token   ) echo $(1pass -p "cli:vaulted:${vault}" totp)     ;;
        esac
    else
        echo "No match found for: ${1}" >> ${CWD}/.autovault.log
        exit 1
    fi
}

#
# This way it can be called as `autovault env` to export VAULTED_ASKPASS as
# the full path to this script
if [[ "${1}" == "env" ]]; then
    echo "export VAULTED_ASKPASS=\"${(%):-%x}\""
else
    ask $@
fi

