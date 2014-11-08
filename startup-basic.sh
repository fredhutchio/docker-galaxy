#!/bin/bash
set -e

servers=`sed -n 's/^\[server:\(.*\)\]/\1/  p' config/galaxy.ini | xargs echo`
for server in $servers; do
    rm -f $server.pid
    echo -n "Starting $server... "
    python ./scripts/paster.py serve config/galaxy.ini --server-name=$server --pid-file=$server.pid --log-file=$server.log &
    sleep 7
    echo "done."
done

tail -f *.log
