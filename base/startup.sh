#!/bin/bash
set -e
service nginx start

cd /galaxy/stable
test -z "$VIRTUAL_ENV" && source /galaxy/galaxy-env/bin/activate
# gosu doesn't set HOME, so set this manually
export PYTHON_EGG_CACHE="/galaxy/.python-eggs"
exec gosu galaxy sh run.sh
