#!/bin/bash
set +eu

# This script expects that DATA_EXPORT_DIR and DATA_EXPORTS variables
# are set, either in the Dockerfile or at runtime. If an exported
# directory doesn't yet exist in EXPORT_DIR, move the container's data
# over before symlinking the export into place.
if [ -d ${DATA_EXPORT_DIR} ]; then
    for dir in ${DATA_EXPORTS}; do
        # If the directory doesn't exist in /export, copy it over.
        if [ ! -d ${DATA_EXPORT_DIR}/${dir} ]; then
            echo -n "Migrating ${dir} to ${DATA_EXPORT_DIR}$dir... "
            # Since most of this will be many small text files, compress
            # and stream the data (instead of mv) in case /export is
            # actually mounted over a network.
            tar cpz -C / ${dir} 2> /dev/null | tar xpzf - -C ${DATA_EXPORT_DIR}
            echo "done."
        fi
        # Unlink the container directory and symlink the exported one in.
        echo -n "Symlinking ${DATA_EXPORT_DIR}$dir into place... "
        rm -rf ${dir}
        ln -s ${DATA_EXPORT_DIR}/${dir} ${dir}
        echo "done."
    done
fi
