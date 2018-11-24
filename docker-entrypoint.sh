#!/bin/bash
[[ -n "${DEBUG:-}" ]] && set -x
set -eu -o pipefail

README_FILE=/README.md

function env_list() {
    sed '/^## Variables/,/^##/!d' "$README_FILE" | grep -Eo "^- \`[_A-Z]+\`\$" | grep -Eo '[_A-Z]+'
}

function env_help() {
    grep -A1 -F -- "- \`$1\`" "$README_FILE" | sed -e 1d -e 's/^ \+//'
}

function err() {
    echo -e "$@" >&2
}


FOUND_ERROR=false
for ENVNAME in $(env_list); do
    if eval "test -z \"\${${ENVNAME}:-}\""; then
        err "\\nFatal: \`${ENVNAME}\` is empty.\\n\\t$(env_help "${ENVNAME}")"
        FOUND_ERROR=true
    fi
done

if "$FOUND_ERROR"; then
    err "\\nExit in 10 seconds."
    sleep 10
    exit 1
fi

BACKUP_SCRIPT="${BASH_SOURCE%/*}/postgres-backup.sh"

if grep '^\(http\|https\|ftp\)://' <<< "$PGP_KEY" &>/dev/null; then
    echo "Download PGP key from $PGP_KEY ..." >&2
    wget --no-check-certificate -O /pgp-key.txt "$PGP_KEY"
    PGP_KEY=/pgp-key.txt
fi

if [[ -f "${PGP_KEY}" ]]; then
    echo "Import PGP key from local file $PGP_KEY ..." >&2
    PGP_KEY="$(gpg --import "$PGP_KEY" |& grep -o '[0-9A-F]\{16,\}')"
    export PGP_KEY
fi

function receive_gpg_key() {
    local pgp_key
    pgp_key="$1"

    declare -a keyservers
    IFS="|, " read -r -a keyservers <<< "${PGP_KEYSERVER}"

    for server in "${keyservers[@]}"; do
        gpg --keyserver "${server}" --recv-keys "${pgp_key}" && return 0;
    done
    return 1
}

while ! gpg --list-key "${PGP_KEY}"; do
    receive_gpg_key "${PGP_KEY}" && break;
    echo "Error in retriving PGP key ${PGP_KEY} from ${PGP_KEYSERVER}, retry in 5 seconds ..."
    sleep 5
done

gpg --update-trustdb --trusted-key "${PGP_KEY}"

export -p | grep '\(AWS\|BACKUP\|PGP\|POSTGRES\|DEBUG\|TZ\)' > /etc/profile.d/s3.sh

echo "${BACKUP_SCHEDULE} root $BACKUP_SCRIPT >/dev/null" | /usr/bin/tee /etc/cron.d/backup

echo "${POSTGRES_HOST:=localhost}:5432:${POSTGRES_DB}:${POSTGRES_USER}:${POSTGRES_PASSWORD}" > "$HOME/.pgpass"
chmod go-rwx "$HOME/.pgpass"

echo "PostgreSQL host: ${POSTGRES_HOST}, user: ${POSTGRES_USER}"

case "$1" in
    cron)
        echo "Backing up ${POSTGRES_DB} at '${BACKUP_SCHEDULE}' ..."
        exec /usr/sbin/cron -f -L 15
        ;;
    backup)
        exec "$BACKUP_SCRIPT"
        ;;
    *)
        if [[ -x "$1" ]]; then
            exec "$@"
        else
            cat "$README_FILE" >&2
        fi
        ;;
esac
