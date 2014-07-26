#!/bin/bash
set -e

# Replace this shell with the new Galaxy process.
exec su -c "sh run.sh" galaxy
