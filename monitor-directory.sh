#!/bin/bash

declare -r my_watch_dir="${1:?Error, need directory to monitor!}"
declare -r my_output_dir="${2:?Error, need directory to put output in!}"

pushd "$my_watch_dir" || exit 1

systemd-notify --ready
while read -r my_created_file; do
    if [[ "$my_created_file" =~ .*\.mph ]]; then
        systemd-notify --status="Processing $my_created_file"

        declare my_out_file="${my_created_file%.mph}_out.mph"
        declare my_user=''
        my_user="$(stat -c '%U' "$my_created_file")"
        declare my_unit_name="comsol-${my_user}-${my_created_file}.service"
        declare my_working_directory="${RUNTIME_DIRECTORY}/${my_unit_name}.d"

        install -D \
            --owner="$my_user" \
            --mode='0600' \
            --preserve-timestamps \
            --target-directory "$my_working_directory" \
            "$my_created_file"

        systemd-run --unit="$my_unit_name" \
            --service-type=oneshot \
            --uid="$my_user" \
            --property="After=${my_last_unit_name:-nothing.service}" \
            --property="PrivateTmp=true" \
            --working-directory="$my_working_directory" \
            --no-block \
            -- /usr/bin/comsol batch -inputfile "$my_created_file" -outputfile "$my_output_dir/$my_out_file"

        my_last_unit_name="$my_unit_name"
    fi
    systemd-notify --status="Waiting for files…"
done < <(inotifywait --event create --format "%f" --monitor --quiet "$my_watch_dir")
