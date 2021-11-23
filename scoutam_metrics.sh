#!/bin/bash

## Manager check, if not manager, abort
me=$HOSTNAME
manager=$(samcli system | grep "scheduler name" | cut -d':' -f 2 | sed 's/\ //g')

if [ "${me}" != "${manager}" ]; then
	## Gather "samcli status"
	is_valid_arch=$(sudo samcli status | grep "ARCHSET: Valid configuration loaded")
	is_running=$(sudo samcli status | grep "SCHEDULER IS RUNNING")

	if [ -n "${is_running}" ]; then
	        scheduler_run_error=0
	else
	        scheduler_run_error=1
	fi

	if [ -n "${is_valid_arch}" ]; then
	        arch_valid_error=0
	else
	        arch_valid_error=1
	fi
	echo "sam_metrics,metric_type=status scheduler_run_error=${scheduler_run_error},arch_valid_error=${arch_valid_error}"
	exit 0
fi

## Create tmp file and start using it
tfile=$(mktemp /tmp/sam.XXXXXX)
sudo samcli metrics | tail -n +2 > ${tfile}

## Gather "samcli metrics"
while IFS= read -r line; do
	metric_type=$(echo ${line} | cut -d',' -f 1)
	metric=$(echo ${line} | cut -d':' -f 1 | cut -d',' -f 2)
	value=$(echo ${line} | cut -d':' -f 2 | awk '{$1=$1;print}')
	echo "sam_metrics,metric_type=${metric_type} ${metric}=${value}"
done < "${tfile}"

## Gather "samcli resource"
sudo samcli resource | tail -n +2 | cut -d' ' -f 2- | sed -e 's/^[[:space:]]*//' | sed 's/\ \ /,/g' | sed 's/,\ /,/g' | sed 's/,,/,/g' | sed 's/\ /_/g' | sed '/^[[:space:]]*$/d' > ${tfile}

while IFS= read -r line; do
	IFS="," read resource_type name state_string home <<< $(echo ${line})
	home_host=$(echo ${home} | sed 's/,/_/g')
        echo "sam_metrics,metric_type=resource,resource_type=${resource_type},name=${name},home_host=${home_host},state_string=${state_string} count=1"
IFS=' '
done < "${tfile}"

## Gather "samcli status"
is_valid_arch=$(sudo samcli status | grep "ARCHSET: Valid configuration loaded")
is_running=$(sudo samcli status | grep "SCHEDULER IS RUNNING")

if [ -n "${is_running}" ]; then
	scheduler_run_error=0
else
	scheduler_run_error=1
fi

if [ -n "${is_valid_arch}" ]; then
	arch_valid_error=0
else
	arch_valid_error=1
fi
echo "sam_metrics,metric_type=status scheduler_run_error=${scheduler_run_error},arch_valid_error=${arch_valid_error}"

minute=$(date +%M)
if ! (( $minute % 5 )) ; then
	## Gather Catalog Pool Stats
	tb_standard () {
	case $1 in
	PiB)
		out=$(echo "scale=4;$2*1024" | bc)
		echo "${out}"
		;;
	TiB)
		echo "$2"
		;;
	GiB)
		out=$(echo "scale=4;$2/1024" | bc)
		echo "${out}"
		;;
	MiB)
		out=$(echo "scale=4;$2/1024/1024" | bc)
		echo "${out}"
		;;
	B)
		echo "0"
		;;
	esac
	}

	sudo samcli catalog pool | grep -v "historian" | tail -n +3 | head -n -1 | awk '{print $2" "$3" "$4" "$5" "$6" "$7" "$8" "$9}' > "${tfile}"

	while IFS= read -r line; do
	        IFS=" " read pool_name tape_count total_cap_raw tot_unit used_cap_raw used_unit avail_cap_raw avail_unit <<< $(echo ${line})
		total_capacity=$(tb_standard ${tot_unit} ${total_cap_raw})
		used_capacity=$(tb_standard ${used_unit} ${used_cap_raw})
		avail_capacity=$(tb_standard ${avail_unit} ${avail_cap_raw})
		echo "scoutam_pool_usage,poolname=${pool_name} tape_count=${tape_count},total_tb=${total_capacity},used_tb=${used_capacity},avail_tb=${avail_capacity}"
	IFS=' '
	done < "${tfile}"

	## Gather Catalog Info
	sudo samcli catalog | sed -n '/HOME/,$p' | tail -n +2 | head -n -1 > "${tfile}"
	pools=($(awk '{print $8}' "${tfile}" | sort -u | grep -v "POOL" | xargs))
	for p in ${pools[@]}
	do
		needs_audit=$(awk -v p="$p" '$8 == p {print $NF}' "${tfile}" | grep "A" | wc -l)
		current_in_use=$(awk -v p="$p" '$8 == p {print $NF}' "${tfile}" | grep "i" | wc -l)
		labeled=$(awk -v p="$p" '$8 == p {print $NF}' "${tfile}" | grep "l" | wc -l)
		Error=$(awk -v p="$p" '$8 == p {print $NF}' "${tfile}" | grep "E" | wc -l)
		media_home=$(awk -v p="$p" '$8 == p {print $NF}' "${tfile}" | grep "o" | wc -l)
		clean_media=$(awk -v p="$p" '$8 == p {print $NF}' "${tfile}" | grep "C" | wc -l)
		write_protected=$(awk -v p="$p" '$8 == p {print $NF}' "${tfile}" | grep "W" | wc -l)
		read_only=$(awk -v p="$p" '$8 == p {print $NF}' "${tfile}" | grep "R" | wc -l)
		draining=$(awk -v p="$p" '$8 == p {print $NF}' "${tfile}" | grep "c" | wc -l)
		unavailable=$(awk -v p="$p" '$8 == p {print $NF}' "${tfile}" | grep "U" | wc -l)
		full=$(awk -v p="$p" '$8 == p {print $NF}' "${tfile}" | grep "f" | wc -l)
		foreign=$(awk -v p="$p" '$8 == p {print $NF}' "${tfile}" | grep "Z" | wc -l)
		echo "scoutam_catalog_stats,pool=${p} audit=${needs_audit},inuse=${current_in_use},labeled=${labeled},error=${Error},media_home=${media_home},cleaning_media=${clean_media},write_protected=${write_protected},read_only=${read_only},draining=${draining},unavailable=${unavailable},full=${full},foreign=${foreign}"
	done

	while IFS= read -r line; do
	        IFS=" " read home slot tapename mtype mounts total_cap cap_remaining pool_name lineend <<< $(echo ${line})
	        echo "scoutam_tape_stats,poolname=${pool_name},tapename=${tapename} mounts=${mounts},cap_remaining_mb=${cap_remaining},total_cap_mb=${total_cap}"
	IFS=' '
	done < "${tfile}"

	## Gather Tape Alerts
fi
rm -rf ${tfile}
