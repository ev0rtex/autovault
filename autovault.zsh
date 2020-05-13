#!/usr/bin/env zsh

CWD="$(cd "$(dirname "${(%):-%x}")";pwd -P)"
SCRIPT="$(readlink -f ${(%):-%x})"
TMP_BASE="${TMPDIR:-/tmp/}$(basename ${SCRIPT%.*} 2>/dev/null)"

# Backend config + defaults
BACKEND="${AUTOVAULT_BACKEND:-1pass}"
BACKEND_PREFIX="${AUTOVAULT_BACKEND_PREFIX}"
case "${BACKEND}" in
    1pass  ) BACKEND_PREFIX="${BACKEND_PREFIX:-cli:vaulted:}" ;;
    gopass ) BACKEND_PREFIX="${BACKEND_PREFIX:-${GOPASS_MOUNT:-inst/}cli/vaulted/}" ;;
esac


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
        out+=$(hex $(( $(ord ${data:$i:1}) ^ $(ord ${key:$(( i % ${#key} )):1}) )))
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
# Backends                                        #
# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= #

backend_1pass() {
    local action="${1}"
    local vault="${2}"
    local entry="${3}"
    local value="${4}"
    case "${1}" in
        fetch )
            [[ "${entry}" == "password" ]] && echo $(1pass -p "${BACKEND_PREFIX}${vault}" password) && return 0
            [[ "${entry}" == "otp" ]]      && echo $(1pass -p "${BACKEND_PREFIX}${vault}" totp)     && return 0
            ;;
        write )
            if [[ "${entry}" == "password" ]]; then
                local opsession="$(gpg -qdr ${$(grep self_key ${HOME}/.1pass/config)##*=} ~/.1pass/cache/_session.gpg)"
                if [[ -z "$(backend_${BACKEND} fetch "${vault}" password)" ]]; then
                    echo "Creating an entry named '${BACKEND_PREFIX}${vault}' in 1Password. Be sure to update it with MFA if needed" > /dev/tty
                    echo "${opsession}" | \
                        op create item Password "$(op encode <<< '{"password":"'"${value}"'"}')" --title="${BACKEND_PREFIX}${vault}" 2>&1 > /dev/null
                    echo -en "Refreshing 1pass cache..." > /dev/tty; 1pass -r > /dev/null; echo "done" > /dev/tty
                else
                    echo "Updating existing entries with the '${BACKEND}' backend is not currently supported (see: https://discussions.agilebits.com/discussion/84324/cli-delete-update-logins)" > /dev/tty
                    return 1
                fi
            else
                echo "The specified action '${action}' is not currently supported for writing with the '${BACKEND}' backend" > /dev/tty
                return 1
            fi
            ;;
    esac
}

backend_gopass() {
    local action="${1}"
    local vault="${2}"
    local entry="${3}"
    local value="${4}"
    case "${1}" in
        fetch )
            [[ "${entry}" == "password" ]] && echo $(gopass show -f -o "${BACKEND_PREFIX}${vault}" 2>/dev/null)                 && return 0
            [[ "${entry}" == "otp" ]]      && echo $(gopass otp        "${BACKEND_PREFIX}${vault}" 2>/dev/null | cut -f1 -d' ') && return 0
            ;;
        write )
            # Write a password
            if [[ "${entry}" == "password" ]]; then
                if [[ -z "$(backend_${BACKEND} fetch "${vault}" password)" ]]; then
                    echo "Creating an entry named '${BACKEND_PREFIX}${vault}' in gopass. Be sure to update it with MFA if needed" > /dev/tty
                    gopass insert -f "${BACKEND_PREFIX}${vault}" <<< "${value}"
                else
                    echo "Updating existing entries with the '${BACKEND}' backend is not yet supported" > /dev/tty
                    return 1
                fi

            # Write a TOTP
            else
                echo "The specified action '${action}' is not currently supported for writing with the '${BACKEND}' backend" > /dev/tty
                return 1
            fi
            ;;
    esac
}

# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= #
# The askpass responder                           #
# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= #

ask() {
    if [[ ${1} =~ "'([^']+)' ((new|confirm) password|password|MFA token)([^:]+)?:" ]]; then
        local vault="${match[1]}"
        local pwhsh="$(shasum <<< "${TMP_BASE}.$(stat -c %Y ${SCRIPT}).${vault}")"
        local pwtmp="${TMP_BASE}.$(awk '{print substr($1,1,12)}' <<< ${pwhsh})"
        local pwkey="$(awk '{print substr($1,length($1)-11,12)}' <<< ${pwhsh})"

        #
        # New password
        if [[ -n "${match[3]}" ]]; then
            if [[ "${match[3]}" == "new" ]]; then
                while true; do
                    echo -n "New password: "           > /dev/tty
                    read -s pw                         < /dev/tty
                    echo                               > /dev/tty
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
                # Fetch the validated password
                local pw=""
                if [[ -f "${pwtmp}" ]]; then
                    pw="$(cat ${pwtmp} | dec ${pwkey})"
                    rm ${pwtmp}
                else
                    echo "Something went wrong obtaining the entered password...falling back to generating a random password for you" > /dev/tty
                    pw="$(head -c32 /dev/urandom | shasum -a 256 | cut -f1 -d' ')"
                fi

                # Save the password using the chosen backend
                if [[ -n "${pw}" ]]; then
                    backend_${BACKEND} write "${vault}" password "${pw}"
                    echo -n "${pw}"
                fi
            fi
        fi

        #
        # Inject requested credential from 1password
        case "${match[2]}" in
            password ) backend_${BACKEND} fetch "${vault}" password ;;
            *token   ) backend_${BACKEND} fetch "${vault}" otp      ;;
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

