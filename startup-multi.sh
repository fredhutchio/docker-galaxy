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

#####

# Start a Galaxy process and wait for a 200 OK. This will
# automatically download missing eggs, install defaults for missing
# files, and prepare the database, and is generally a good sanity
# check before proceeding.
su -c "sh run.sh --daemon" galaxy
wait_for_ok http://127.0.0.1:80

# Stop Galaxy again so we can finish setting up.
su -c "sh run.sh --stop-daemon" galaxy

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

# TODO dynamic
if grep -q web0 universe_wsgi.ini; then
    echo "servers already defined in universe_wsgi.ini, skipping"
else
    define_galaxy_server web0 8080 7 >> universe_wsgi.ini
    define_galaxy_server web1 8081 7 >> universe_wsgi.ini
    define_galaxy_server worker0 8090 5 >> universe_wsgi.ini
    define_galaxy_server worker1 8091 5 >> universe_wsgi.ini
fi

cat <<EOF > job_conf.xml
<?xml version="1.0"?>
<job_conf>
    <plugins workers="4">
        <plugin id="local" type="runner" load="galaxy.jobs.runners.local:LocalJobRunner"/>
    </plugins>
    <handlers default="workers">
EOF

# TODO dynamic
cat <<EOF >> job_conf.xml
        <handler id="worker0" tags="workers"/>
        <handler id="worker1" tags="workers"/>
EOF

cat <<EOF >> job_conf.xml
    </handlers>
    <destinations>
        <destination id="local" runner="local"/>
    </destinations>
</job_conf>
EOF

GALAXY_SERVERS="web0 worker0 worker1"
for SERVER in ${GALAXY_SERVERS}; do
    echo -n "Starting ${SERVER}... "
    su -c "python ./scripts/paster.py serve universe_wsgi.ini --server-name=${SERVER} --pid-file=${SERVER}.pid --log-file=${SERVER}.log --daemon" galaxy
    echo "ok"
done

# Reconfigure nginx for the new web processes.
# TODO dynamic
# if grep -q 'server 127\.0\.0\.1:8081' /etc/nginx/nginx.conf; then
#     echo "servers already defined in nginx.conf, skipping"
# else
#     sed -i 's|\(server 127\.0\.0\.1:8080\);|\1; server 127.0.0.1:8081;|' /etc/nginx/nginx.conf
#     service nginx reload
# fi

# Trap SIGINT so we can try to shut down cleanly.
trap '{ echo -n "Shutting down... "; pkill -INT -f paster.py; sleep 10; echo " ok"; exit 0; }' SIGINT EXIT
tail -f web*.log worker*.log

# Turn over this process to a shell for testing.
#exec /bin/bash
