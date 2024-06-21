#!/bin/bash

tfile=$(mktemp /tmp/scoutq.XXXXXX)
source /etc/telegraf/versity/scout_config

samcli quota use --uid | tail -n +2 | awk '{print $2","$4","$5","$6","$7","$8","$9","$10","$11}' > "${tfile}"

while read -r p; do
	IFS="," read -r user_id online_files online_file_limit online_size online_size_limit total_files total_file_limit total_size total_size_limit <<< $(echo "${p}")
	user_name=$(awk -v u="${user_id}" -F: '$3 == u {print $1}' ${admin_dir}/getent_passwd)
        if [ -z "${user_name}" ]; then
        	user_name="NotFound"
        fi
	echo "scoutfs_quota,quota_type=user,fs=${fs},user_id=${user_id,user_name=${user_name}} online_files=${online_files},online_file_limit=${online_file_limit},online_size=${online_size},online_size_limit=${online_size_limit},total_files=${total_files},total_file_limit=${total_file_limit},total_size=${total_size},total_size_limit=${total_size_limit}" | sed 's/=-,/=0,/g'
done <"${tfile}"

samcli quota use --gid | tail -n +2 | awk '{print $2","$4","$5","$6","$7","$8","$9","$10","$11}' > "${tfile}"

while read -r p; do
        IFS="," read -r group_id online_files online_file_limit online_size online_size_limit total_files total_file_limit total_size total_size_limit <<< $(echo "${p}")
	group_name=$(awk -v g="${group_id}" -F: '$3 == g {print $1}' ${admin_dir}/getent_group)
        if [ -z "${group_name}" ]; then
        	group_name="NotFound"
        fi
        echo "scoutfs_quota,quota_type=group,fs=${fs},group_id=${group_id},group_name=${group_name} online_files=${online_files},online_file_limit=${online_file_limit},online_size=${online_size},online_size_limit=${online_size_limit},total_files=${total_files},total_file_limit=${total_file_limit},total_size=${total_size},total_size_limit=${total_size_limit}" | sed 's/=-,/=0,/g'
done <"${tfile}"

samcli quota use --proj | tail -n +2 | awk '{print $2","$4","$5","$6","$7","$8","$9","$10","$11}' > "${tfile}"

while read -r p; do
        IFS="," read -r project_id online_files online_file_limit online_size online_size_limit total_files total_file_limit total_size total_size_limit <<< $(echo "${p}")
        project_name=$(awk -v p="${project_id}" -F: '$3 == p {print $1}' ${admin_dir}/getent_group)
        if [ -z "${project_name}" ]; then
        	project_name="NotFound"
        fi
        echo "scoutfs_quota,quota_type=project,fs=${fs},project_id=${project_id},project_name=${project_name} online_files=${online_files},online_file_limit=${online_file_limit},online_size=${online_size},online_size_limit=${online_size_limit},total_files=${total_files},total_file_limit=${total_file_limit},total_size=${total_size},total_size_limit=${total_size_limit}" | sed 's/=-,/=0,/g'
done <"${tfile}"

rm -rf "${tfile}"
