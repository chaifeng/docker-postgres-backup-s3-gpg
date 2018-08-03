#!/bin/bash
source /etc/profile.d/s3.sh

[[ -n "${DEBUG:-}" ]] && set -x
set -eu -o pipefail

if [[ "$-" = *x* ]]; then
  exec 42>>"${DEBUG_LOG_FILE:=/debug.txt}"
  export BASH_XTRACEFD=42
fi

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

AWS_CLI_OPTS=()
[[ -n "${AWS_ENDPOINT}" ]] && AWS_CLI_OPTS+=(--endpoint-url "$AWS_ENDPOINT")

S3_FILENAME="${BACKUP_BUCKET}/$(date "+${BACKUP_PREFIX}${POSTGRES_DB}${BACKUP_SUFFIX}")"

function s3() {
    aws "${AWS_CLI_OPTS[@]}" s3 "$@"
}

pg_dump -h "${POSTGRES_HOST}" -U "${POSTGRES_USER}" "${POSTGRES_DB}" 2>/dev/null \
    | gpg --encrypt -r "${PGP_KEY}" --compress-algo zlib --quiet \
    | s3 cp - "s3://${S3_FILENAME}" \
    || s3 rm "s3://${S3_FILENAME}"

echo "$S3_FILENAME"
