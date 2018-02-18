#!/bin/bash
[[ -n "${DEBUG:-}" ]] && set -x
set -eu -o pipefail

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

source /etc/profile.d/s3.sh

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
