#!/bin/bash
set -eu

# This script expects that DATA_EXPORT_DIR and DATA_EXPORTS variables
# are set, either in the Dockerfile or at runtime. If an exported
# directory doesn't yet exist in EXPORT_DIR, move the container's data
# over before symlinking the export into place.
if [ -d ${DATA_EXPORT_DIR} ]; then
    for source in ${DATA_EXPORTS}; do
        target="${DATA_EXPORT_DIR}${source}"
        target_dir=$(dirname target)

        # If the export doesn't exist in DATA_EXPORT_DIR, copy ours over.
        if [ ! -e ${target} ]; then
            echo -n "Migrating ${source} to ${target}... "
            if [ -d ${source} ]; then
                # Since most of this will be many small text files,
                # compress and stream the data (instead of mv) in case
                # DATA_EXPORT_DIR is actually mounted over a network.
                tar cpz -C / ${source} 2> /dev/null | tar xpzf - -C ${DATA_EXPORT_DIR}
            else
                [ -d ${target_dir} ] || mkdir -p ${target_dir}
                cp ${source} ${target}
            fi
            echo "done."
        fi
        # Unlink the source and symlink the target in.
        echo -n "Symlinking ${target} into place... "
        source_tmp=$(mktemp -u ${source}.XXXX)
        mv -f ${source} ${source_tmp}
        ln -s ${target} ${source} && rm -rf ${source_tmp}
        echo "done."
    done
fi
