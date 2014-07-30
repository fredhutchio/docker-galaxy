#!/bin/bash
set -e

# "Production"-style startup script
#
# Galaxy in its default configuration has a tendency to hang for a bit
# when e.g. submitting complex workflow jobs because of the Python
# GIL. Galaxy's way around that is to spawn dedicated web and job
# handlers. This script makes it easy to spawn these processes, as
# well as the mountpoint hooks and barebones nginx load balancer in
# front of the web processes from the base image, inside the
# container.
#
# The excess of scripting is because I'd rather avoid including the
# config files themselves in this repo, instead preferring to modify
# the default config one line at a time in either the Dockerfile
# (baking the change into the image) or the docker entrypoint or
# startup scripts (making the change as needed just before starting
# the server).

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

# usage: galaxy_server <ID> <PORT> <WORKERS>
define_galaxy_server() {
    cat <<EOF

[server:$1]
use = egg:Paste#http
host = 127.0.0.1
port = $2
use_threadpool = True
threadpool_workers = $3
EOF
}

#####

# Start a Galaxy process and wait for a 200 OK. This will
# automatically download missing eggs, install defaults for missing
# files, and prepare the database, and is generally a good sanity
# check before proceeding.
su -c "sh run.sh --daemon" galaxy
wait_for_ok http://127.0.0.1:80

# Stop Galaxy again so we can finish setting up.
su -c "sh run.sh --stop-daemon" galaxy

# If there's a universe_wsgi.ini in /root/private, use it instead of
# adding to the default.
if [ -r /root/private/universe_wsgi.ini ]; then
    echo -n "Installing universe_wsgi.ini from /root/private... "
    cp /root/private/universe_wsgi.ini /galaxy/stable/universe_wsgi.ini
    chown galaxy:galaxy universe_wsgi.ini
    echo "done."
else
    # Already in universe_wsgi.ini is the 'main' server on 8080.
    define_galaxy_server worker0 8090 5 >> universe_wsgi.ini
    define_galaxy_server worker1 8091 5 >> universe_wsgi.ini
fi

# If there's a job_conf.xml in /root/private, use it instead of the
# heredoc'd default.
if [ -r /root/private/job_conf.xml ]; then
    echo -n "Installing job_conf.xml from /root/private... "
    cp /root/private/job_conf.xml /galaxy/stable/job_conf.xml
    chown galaxy:galaxy job_conf.xml
    echo "done."
else
    cat <<EOF > job_conf.xml
<?xml version="1.0"?>
<job_conf>
    <plugins workers="4">
        <plugin id="local" type="runner" load="galaxy.jobs.runners.local:LocalJobRunner"/>
    </plugins>
    <handlers default="workers">
        <handler id="worker0" tags="workers"/>
        <handler id="worker1" tags="workers"/>
    </handlers>
    <destinations>
        <destination id="local" runner="local"/>
    </destinations>
</job_conf>
EOF
fi

# If there's a tool_conf.xml in /root/private, use it instead of the
# distribution default.
if [ -r /root/private/tool_conf.xml ]; then 
    echo -n "Installing tool_conf.xml from /root/private... "
    cp /root/private/tool_conf.xml /galaxy/stable/tool_conf.xml
    chown galaxy:galaxy tool_conf.xml
    echo "done."
fi

# Use Galaxy's rolling restart script to start the servers.
su -c "bash rolling_restart.sh" galaxy

# Trap SIGINT so we can try to shut down cleanly.
trap '{ echo -n "Shutting down... "; pkill -INT -f paster.py; sleep 10; echo " ok"; exit 0; }' SIGINT EXIT
tail -f main.log worker*.log

# Turn over this process to a shell for testing.
#exec /bin/bash
