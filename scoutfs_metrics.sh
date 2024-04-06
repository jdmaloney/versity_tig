#!/bin/bash

source /etc/telegraf/versity/scout_config

## Manager check, if not manager, abort
me=$HOSTNAME
manager=$(sudo samcli system | grep "scheduler name" | cut -d':' -f 2 | sed 's/\ //g')

if [ "${me}" != "${manager}" ]; then
        exit 0
fi

## Usage of cache metadata and data
while IFS= read -r line; do
        IFS=" " read -r lun_type lun_size total used free used_percent <<< "$(echo "${line}")"
        echo "versity_df,mount_path=${mount_path},lun_type=${lun_type} size=\"${lun_size}\",total_size=${total},used=${used},free=${free},used_percent=${used_percent}"
done < <(scoutfs df -p ${mount_path} | tail -n +2)

## Dump Output to working file
tfile=$(mktemp /tmp/scoutfs_stat.XXXXXX)
sudo samcli fs stat > "${tfile}"

## Parse our values from working file
read -r data_used meta_used < <(grep "Used:" ${tfile} | awk '{print $3}' | cut -d'%' -f 1 | xargs)
read -r data_total dt_unit data_free df_unit meta_total mt_unit meta_free mf_unit < <(grep -v Watermark ${tfile} | grep -v "Used:" | awk '{print $3" "$4}' | xargs)
read -r high_water_per high_water_tb high_water_unit low_water_per low_water_tb low_water_unit < <(grep "Watermark" ${tfile} | awk '{print $3" "$4" "$5}' | sed 's/[%(]//g' | sed 's/)//g' | xargs)

## Unit Check Section
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
total_data=$(tb_standard ${dt_unit} ${data_total})
free_data=$(tb_standard ${df_unit} ${data_free})
total_meta=$(tb_standard ${mt_unit} ${meta_total})
free_meta=$(tb_standard ${mf_unit} ${meta_free})
low_water_t=$(tb_standard ${low_water_unit} ${low_water_tb})
high_water_t=$(tb_standard ${high_water_unit} ${high_water_tb})

## Ship to InfluxDB
echo "scoutfs_usage,fs=${fs} data_total_tb=${total_data},data_free_tb=${free_data},data_used_percent=${data_used},meta_total_tb=${total_meta},meta_free_tb=${free_meta},meta_used_percent=${meta_used},highwater_percent=${high_water_per},high_water_tb=${high_water_t},low_water_percent=${low_water_per},low_water_tb=${low_water_t}"

## Parse of Cache Stats
samcli fs acct -H -c | tail -n +2 | head -n -1 > ${tfile}

damaged_files=$(tail -n 1 ${tfile} | cut -d' ' -f 5)
read -r pending_files pending_raw_data noarchive_files noarchive_raw_data unmatched_archset_files unmatched_archset_raw_data releaseable_files releaseable_raw_data < <(grep "count" ${tfile} | cut -d':' -f 2- | sed 's/data://g' | xargs)
t_standard () {
        case $1 in
        P)
                out=$(echo "scale=4;$2*1024" | bc)
                echo "${out}"
                ;;
        T)
                echo "$2"
                ;;
        G)
                out=$(echo "scale=4;$2/1024" | bc)
                echo "${out}"
                ;;
        M)
                out=$(echo "scale=4;$2/1024/1024" | bc)
                echo "${out}"
                ;;
        B)
                echo "0"
                ;;
	0)
		echo "0"
		;;
       esac
}
pending_data=$(t_standard $(echo ${pending_raw_data} | rev | cut -c 1) $(echo ${pending_raw_data} | rev | cut -c 2- | rev))
noarchive_data=$(t_standard $(echo ${noarchive_raw_data} | rev | cut -c 1) $(echo ${noarchive_raw_data} | rev | cut -c 2- | rev))
unmatched_archset_data=$(t_standard $(echo ${unmatched_archset_raw_data} | rev | cut -c 1) $(echo ${unmatched_archset_raw_data} | rev | cut -c 2- | rev))
releaseable_data=$(t_standard $(echo ${releaseable_raw_data} | rev | cut -c 1) $(echo ${releaseable_raw_data} | rev | cut -c 2- | rev))


echo "scoutfs_cache_stats,fs=${fs} pending_files=${pending_files},pending_data_tb=${pending_data},noarchive_files=${noarchive_files},noarchive_data_tb=${noarchive_data},unmatched_archset_files=${unmatched_archset_files},unmatched_archset_data_tb=${unmatched_archset_data},releaseable_files=${releaseable_files},releaseable_data_tb=${releaseable_data},damaged_files=${damaged_files}"

rm -rf ${tfile}
