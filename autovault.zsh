#!/usr/bin/env zsh

CWD="$(cd "$(dirname "${(%):-%x}")";pwd -P)"
SCRIPT="$(readlink -f ${(%):-%x})"
TMP_BASE="${TMPDIR:-/tmp/}$(basename ${SCRIPT%.*} 2>/dev/null)"


# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= #
# Super ximple XOR encryption for our temp files  #
# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= #

chr() { printf \\$(printf '%03o' ${1}) }
ord() { printf '%d' "'${1}" }
hex() { printf '%02x' "${1}" }
asc() { echo -en "\x${1}" }
enc() {
    local key=${1} data= out=; read data
    for (( i=0; i<${#data}; i++ )); do
        out+=$(hex $(( $(ord ${data:$i:1}) ^ $(ord ${key:$(( i % ${#key})):1}) )))
    done
    echo -n "${out}"
}
dec() {
    local key=${1} data= out=; read data
    for (( i=0; $((i*2))<${#data}; i++ )); do
        out+=$(chr $(( $(ord $(asc ${data:$((i * 2)):2})) ^ $(ord ${key:$(( i % ${#key} )):1}) )))
    done
    echo -n "${out}"
}

# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= #
# The askpass responder                           #
# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= #

ask() {
    if [[ ${1} =~ "'([^']+)' ((new|confirm) password|password|MFA token)([^:]+)?:" ]]; then
        local vault="${match[1]}"
        local pwhsh="$(shasum <<< "${TMP_BASE}.$(stat -c %Y ${SCRIPT})")"
        local pwtmp="${TMP_BASE}.$(awk '{print substr($1,1,12)}' <<< ${pwhsh})"
        local pwkey="$(awk '{print substr($1,length($1)-11,12)}' <<< ${pwhsh})"

        #
        # New password
        if [[ -n "${match[3]}" ]]; then
            if [[ "${match[3]}" == "new" ]]; then
                while true; do
                    echo -n "New password: "         > /dev/tty
                    read -s pw                       < /dev/tty
                    echo                             > /dev/tty
                    echo -n "New password (confirm): " > /dev/tty
                    if [[ "$(read -s pw_check < /dev/tty; echo -n "${pw_check}")" == "${pw}" ]]; then
                        echo -n "${pw}" | enc ${pwkey} > ${pwtmp}
                        echo -n "${pw}"
                        echo > /dev/tty
                        break
                    else
                        echo -e "\nThe passwords you entered did not match" > /dev/tty
                    fi
                done
            elif [[ "${match[3]}" == "confirm" ]]; then
                cat ${pwtmp} | dec ${pwkey}; rm ${pwtmp}
            fi
        fi

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
# This script can be called as `autovault env` to export VAULTED_ASKPASS as
# the full path to this script (explicitly not following symlinks)
if [[ "${1}" == "env" ]]; then
    echo "export VAULTED_ASKPASS=\"${(%):-%x}\""
else
    ask $@
fi

