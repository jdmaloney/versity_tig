# Versity TIG 
Telegraf Checks and Grafana Dashboards for Monitoring Versity's ScoutFS and ScoutAM with TIG

## ScoutAM
The scoutam_metrics.sh exec script is meant to run every minute on all nodes in the Versity cluster; the script itself will check if it is on the active scheduler and will run additional checks from that machine on a 5 minute cadence.

## ScoutFS
The scoutfs_metrics.sh exec script is meant to run every 5 minutes, it pulls in data about disk cache statistics, data flow from cache to tape, and scoutfs user/group quota information (coming soon).  

## Dashboards and Telegraf Configs
- A sample telegraf config file for the scout* input checks is in this repo as scout_telegraf.conf
- Sample dashboards are coming soon
