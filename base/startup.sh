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

# Configure a postgres db if $DB_NAME is set.
if [[ -n "${DB_NAME}" ]]; then
    DB_CONN="postgresql://${DB_USER:=galaxy}:${DB_PASS:=galaxy}@${DB_PORT_5432_TCP_ADDR}:${DB_PORT_5432_TCP_PORT}/${DB_DATABASE:=galaxy}"
    sed -i 's|^#\?\(database_connection\) = .*$|\1 = '${DB_CONN}'|' universe_wsgi.ini
    sed -i 's|^#\?\(database_engine_option_server_side_cursors\) = .*$|\1 = True|' universe_wsgi.ini
    sed -i 's|^#\?\(database_engine_option_strategy\) = .*$|\1 = threadlocal|' universe_wsgi.ini
fi

# Configure Galaxy admin users if $GALAXY_ADMINS is set.
if [[ -n "${GALAXY_ADMINS}" ]]; then
    sed -i 's|^#\?\(admin_users\) = .*$|\1 = '${GALAXY_ADMINS}'|' universe_wsgi.ini
fi

# If the database or tool-data directories are empty (e.g., if a new
# volume was passed to `docker run`, initialize them from skeletons.

if [[ -z "$(ls -A /galaxy/stable/database)" ]]; then
    tar xvpf database_skel.tar.gz
fi

if [[ -z "$(ls -A /galaxy/stable/tool-data)" ]]; then
    tar xvpf tool-data_skel.tar.gz
fi

# Replace this shell with the new Galaxy process.
exec su -c "sh run.sh" galaxy
