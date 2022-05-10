#!/bin/bash

source /etc/telegraf/versity/scout_config

check=$(grep ${mount_path} /proc/mounts | grep scoutfs)
if [ -n "$check" ]; then
	#It's in /proc/mounts
	proc_check=0
else
	proc_check=1
fi
stat=$(stat ${mount_path}/${check_file})
if [ -n "$stat" ]; then
	#We can stat a file
	stat_check=0
else
	stat_check=1
fi
if [ $proc_check -eq 0 ] && [ $stat_check -eq 0 ]; then
	#All is healthy
	echo "mountcheck,fs=${f} presence=1"
else
	echo "mountcheck,fs=${f} presence=0"
fi
