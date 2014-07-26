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
            return $?
        fi
        echo -n "."
        sleep 5
    done
    echo " ok"
}

#####

# Start the web proxy.
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

# Configure exports. If an exported directory doesn't yet exist on
# /export, move the container's data over before symlinking the export
# into place. GALAXY_EXPORT is set in the Dockerfile or at runtime.
set -u
for dir in ${GALAXY_EXPORT}; do
    # If the directory doesn't exist in /export, copy it over.
    if [ ! -d /export${dir} ]; then
        echo -n "Migrating ${dir} to /export$dir... "
        EXPORT_BASE="/export$(dirname ${dir})"
        # Since most of this will be many small text files, compress
        # and stream the data (instead of mv) in case /export is
        # actually mounted over a network.
        tar cpz -C / ${dir} 2> /dev/null | tar xpzf - -C /export
        echo "done."
    fi
    # Unlink the container directory and symlink the exported one in.
    echo -n "Symlinking /export$dir into place... "
    rm -rf ${dir}
    ln -s /export${dir} ${dir}
    echo "done."
done
set +u

# Move /root/private/ssh into place if it exists.
if [ -d /root/private/ssh ]; then
    echo -n "Configuring ssh... "
    mv /root/private/ssh /galaxy/.ssh
    chmod 700 /galaxy/.ssh
    chmod 600 /galaxy/.ssh/id_rsa
    chown -R galaxy:galaxy /galaxy/.ssh
    echo "done."
fi

# Replace this shell with the supplied command (and any arguments).
exec $@
