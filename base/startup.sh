#!/bin/bash
set -e

# Basic docker-galaxy entrypoint
#
# The base image is mostly self-contained. This script modifies a few
# Galaxy defaults based on supplied environment variables, available
# volumes, etc., and starts the services.

# usage: galaxy_config database_connection "$DB_CONN"
galaxy_config() {
    sed -i 's|^#\?\('"$1"'\) = .*$|\1 = '"$2"'|' /galaxy/stable/universe_wsgi.ini
}

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

#####

service nginx start

cd /galaxy/stable

# Set up a connection string for a database on a linked container.
# Default: postgresql://galaxy:galaxy@HOST:PORT/galaxy
if [ -n "${DB_PORT_5432_TCP_ADDR}" ]; then
    DB_CONN="postgresql://${DB_USER:=galaxy}:${DB_PASS:=galaxy}@${DB_PORT_5432_TCP_ADDR}:${DB_PORT_5432_TCP_PORT}/${DB_DATABASE:=galaxy}"
fi

# Configure a postgres db if $DB_CONN is set, here or otherwise.
if [ -n "${DB_CONN}" ]; then
    galaxy_config database_connection "${DB_CONN}"
    galaxy_config database_engine_option_server_side_cursors "True"
    galaxy_config database_engine_option_strategy "threadlocal"
fi

# Configure Galaxy admin users if $GALAXY_ADMINS is set.
if [ -n "${GALAXY_ADMINS}" ]; then
    galaxy_config admin_users "${GALAXY_ADMINS}"
fi

# If a volume directory is empty (e.g., if a new volume was
# passed to `docker run`), initialize it from a skeleton.

if [ -z "$(ls -A /galaxy/tools)" ]; then
    tar xvpf tools_skel.tar.gz -C /galaxy
fi

if [ -z "$(ls -A /galaxy/stable/database)" ]; then
    tar xvpf database_skel.tar.gz
fi

if [ -z "$(ls -A /galaxy/stable/static)" ]; then
    tar xvpf static_skel.tar.gz
fi

if [ -z "$(ls -A /galaxy/stable/tool-data)" ]; then
    tar xvpf tool-data_skel.tar.gz
fi

# Replace this shell with the new Galaxy process.
exec su -c "sh run.sh" galaxy
