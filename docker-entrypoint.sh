#!/bin/bash
set -e

# Basic docker-galaxy entrypoint
#
# The base image is mostly self-contained. This script modifies a few
# Galaxy defaults based on supplied environment variables, available
# volumes, etc., and starts the services.

# usage: galaxy_config database_connection "$DB_CONN"
galaxy_config() {
    sed -i --follow-symlinks 's|^#\?\('"$1"'\) = .*$|\1 = '"$2"'|' ${GALAXY_HOME}/universe_wsgi.ini
}

# usage: wait_for_ok http://example.com
wait_for_ok() {
    echo -n "waiting for 200 OK..."
    until wget -qO /dev/null $1; do
        if [[ $? > 0 && $? < 8 ]]; then
            return $?
        fi
        echo -n "."
        sleep 5
    done
    echo " ok"
}

#####

GALAXY_ROOT="${GALAXY_ROOT:-/galaxy}"
GALAXY_HOME="${GALAXY_ROOT}/stable"

if [ ${GALAXY_ROOT} != "/galaxy" ]; then
    cd /galaxy
    echo -n "Rerooting Galaxy to ${GALAXY_ROOT}... "
    mkdir -p ${GALAXY_ROOT}
    tar cpz -C /galaxy . | tar xpzf - -C ${GALAXY_ROOT}
    echo "done."

    echo -n "Updating nginx.conf... "
    sed -i 's|/galaxy/stable|'"${GALAXY_HOME}"'|g' /etc/nginx/nginx.conf
    echo "done."
fi

cd ${GALAXY_ROOT}

# Configure exports.
if [ -n "${DATA_EXPORTS}" -a -n "${DATA_EXPORT_DIR}" ]; then
    mkdir -p ${DATA_EXPORT_DIR}

    # Initialize exports from .sample files if they don't exist yet.
    for src in ${DATA_EXPORTS}; do
        if [ ! -e ${src} -a -e ${src}.sample ]; then
            cp -a ${src}.sample ${src}
        fi
    done
    docker-link-exports
fi

cd ${GALAXY_HOME}
chown -R galaxy:galaxy ${GALAXY_ROOT}
chmod -R o=rX static

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

# Move /root/private/ssh into place if it exists.
if [ -d /root/private/ssh ]; then
    echo -n "Configuring ssh... "
    mv /root/private/ssh /galaxy/.ssh
    chmod 700 /galaxy/.ssh
    chmod 600 /galaxy/.ssh/id_rsa
    chown -R galaxy:galaxy /galaxy/.ssh
    echo "done."
fi

# Start the web proxy.
service nginx start

# Replace this shell with the supplied command (and any arguments).
exec $@
