#!/bin/bash

## Configure
source scoutfs_dump_config

## Prep the log area
mkdir -p /var/log/scoutfs
log_file=/var/log/scoutfs/meta_backup.$(date +%Y-%m-%d_%H-%M-%S).log

## Dump the metadata
/usr/bin/samcli fs dump -f ${meta_backup_dir}/mnt.scoutfs.FSmeta.dump.$(date +%Y-%m-%d_%H-%M-%S) -r ${fs_mount_path} > "${log_file}" 2>&1
rc=$?

## Check return code and handle accordingly
if [ ${rc} -ne 0 ]; then
	curl -u ${influxdb_username}:${influxdb_password} -i -XPOST "https://${influxdb_server}:8086/write?db=${influxdb_database}" --data-binary "scoutfs_meta_backup,fs_mount=${fs_mount_path} success=0,files=0,dirs=0,time=0,rate=0"
else
	unflushed_files=$(grep "file has no copies and will be restored as damaged" ${log_file} | wc -l)
        IFS=" " read files dirs time rate <<< "$(tail -n 4 ${log_file} |  cut -d':' -f 2- | awk '{print $1}' | xargs)"
	time_unit=$(echo ${time} | sed 's/[0-9]\|\.//g')
	case $time_unit in
		ms)
			raw_time=$(echo ${time} | sed 's/[a-z]//g')
			final_time="0$(echo "scale=7; ${raw_time}/1000" | bc)"
			;;
		s)
			raw_tim=$(echo ${time} | sed 's/[a-z]//g')
			final_time="${raw_time}"
                        ;;
		m)
			raw_time=$(echo ${time} | sed 's/[a-z]//g')
                        final_time=$(echo "scale=7; ${raw_time}*60" | bc)
                        ;;
	esac

	## Ship to InfluxDB
	curl -u ${influxdb_username}:${influxdb_password} -i -XPOST "https://${influxdb_server}:8086/write?db=${influxdb_database}" --data-binary "scoutfs_meta_backup,fs_mount=${fs_mount_path} success=1,files=${files},dirs=${dirs},run_time=${final_time},rate=${rate},unflushed_files=${unflushed_files}"

fi
