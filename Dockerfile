FROM postgres:9.5.11

ENV AWS_ACCESS_KEY_ID="" \
    AWS_SECRET_ACCESS_KEY="" \
    AWS_DEFAULT_REGION="us-east-1" \
    AWS_ENDPOINT="" \
    BACKUP_SCHEDULE="0 0 * * *" \
    BACKUP_BUCKET="backup" \
    BACKUP_PREFIX="postgres/%Y/%m/%d/postgres-" \
    BACKUP_SUFFIX="-%Y%m%d-%H%M.sql.gz.gpg" \
    PGP_KEY="" \
    PGP_KEYSERVER="hkp://keys.gnupg.net"

#   POSTGRES_HOST POSTGRES_USER POSTGRES_PASSWORD POSTGRES_DB

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
           cron gpgv2 python python-pip \
    && pip install awscli \
    && apt-get clean autoclean \
    && apt-get autoremove --yes \
    && rm -rf /var/lib/{apt,dpkg,cache,log}/ \
    && echo "Done."

COPY *.sh /usr/local/bin/

ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["cron"]
