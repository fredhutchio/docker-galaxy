#!/bin/bash
set -e

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
