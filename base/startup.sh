#!/bin/bash
set -e

# usage: wait_for_ok http://example.com
wait_for_ok() {
    echo -n "waiting for 200 OK..."
    until wget -qO /dev/null $1; do
        if [[ $? > 0 && $? < 8 ]]; then
            echo " error"
            break
        fi
        echo -n "."
        sleep 5
    done
    echo " ok"
}

service nginx start

cd /galaxy/stable
#test -z "$VIRTUAL_ENV" && source /galaxy/galaxy-env/bin/activate

if [[ -n "${DB_NAME}" ]]; then
    DB_CONN="postgresql://${DB_USER:=galaxy}:${DB_PASS:=galaxy}@${DB_PORT_5432_TCP_ADDR}:${DB_PORT_5432_TCP_PORT}/${DB_DATABASE:=galaxy}"
    sed -i 's|^#\?database_connection = .*$|database_connection = '${DB_CONN}'|' universe_wsgi.ini
fi

exec su -c "sh run.sh" galaxy
