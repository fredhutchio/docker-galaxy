#!/bin/bash
set -e

# If a .venv directory exists, assume it's a virtualenv to run in.
if [ -d .venv ]; then
    printf "Activating virtualenv at %s/.venv\n" $(pwd)
    . .venv/bin/activate
fi

# Start the server process(es).
servers=`sed -n 's/^\[server:\(.*\)\]/\1/  p' config/galaxy.ini | xargs echo`
for server in $servers; do
    rm -f $server.pid
    echo -n "Starting $server... "
    python ./scripts/paster.py serve config/galaxy.ini --server-name=$server --pid-file=$server.pid --log-file=$server.log --daemon
    sleep 5
    echo "done."
done

exec tail -f *.log
