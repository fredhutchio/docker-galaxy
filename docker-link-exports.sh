#!/bin/bash
set -eu

# From http://stackoverflow.com/questions/2564634/bash-convert-absolute-path-into-relative-path-given-a-current-directory#comment12808306_7305217
relpath() { python -c "import os.path; print os.path.relpath('$1', '${2:-$PWD}')"; }

# This script expects that DATA_EXPORT_DIR and DATA_EXPORTS variables
# are set, either in the Dockerfile or at runtime. Exports are
# relative to the current working directory. If an exported directory
# doesn't yet exist in DATA_EXPORT_DIR, move the container's data over
# before symlinking the export into place.
if [ -d ${DATA_EXPORT_DIR} ]; then
    for source in ${DATA_EXPORTS}; do
        source_dir=$(dirname $PWD/$source)
        target="${DATA_EXPORT_DIR}/${source}"
        target_dir=$(dirname $target)

        if [ ! -e ${source} -a ! -e ${target} ]; then
            echo "Neither ${source} nor ${target} exist, skipping..."
            continue
        fi

        # If the export doesn't exist in DATA_EXPORT_DIR, copy ours
        # over (if it exists).
        if [ ! -e ${target} -a -e ${source} ]; then
            echo -n "Migrating ${source} to ${target}... "
            if [ -d ${source} ]; then
                # Since most of this will be many small text files,
                # compress and stream the data (instead of mv) in case
                # DATA_EXPORT_DIR is actually mounted over a network.
                tar cpz ${source} | tar xpzf - -C ${DATA_EXPORT_DIR}
            elif [ -f ${source} ]; then
                mkdir -p ${target_dir}
                cp -a ${source} ${target}
            fi
            echo "done."
        fi

        echo -n "Symlinking ${target} into place... "
        if [ -e ${source} ]; then
            # Unlink the source and symlink the target in.
            source_tmp=$(mktemp -u $(dirname ${source})/$(basename ${source}).XXXX)
            mv -f ${source} ${source_tmp}
            ln -s $(relpath ${target} ${source_dir}) ${source} && rm -rf ${source_tmp}
        else
            ln -s $(relpath ${target} ${source_dir}) ${source}
        fi
        echo "done."
    done
fi
