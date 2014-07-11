#!/bin/bash
set -e

service nginx start

cd /galaxy/stable
test -z "$VIRTUAL_ENV" && source /galaxy/galaxy-env/bin/activate

if [ -n "${DB_NAME}" ]; then
    DB_CONN="postgresql://${DB_USER:=galaxy}:${DB_PASS:=galaxy}@${DB_PORT_5432_TCP_ADDR}:${DB_PORT_5432_TCP_PORT}/${DB_DATABASE:=galaxy}"
    sed -i 's|^database_connection = .*$|database_connection = '${DB_CONN}'|' universe_wsgi.ini
fi

exec gosu galaxy sh run.sh
