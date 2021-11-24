# Versity TIG 
Telegraf Checks and Grafana Dashboards for Monitoring Versity's ScoutFS and ScoutAM with TIG

## ScoutAM
The scoutam_metrics.sh exec script is meant to run every minute on all nodes in the Versity cluster; the script itself will check if it is on the active scheduler and will run additional checks from that machine on a 5 minute cadence.

## ScoutFS
The scoutfs_metrics.sh exec script is meant to run every 5 minutes, it pulls in data about disk cache statistics, data flow from cache to tape, and scoutfs user/group quota information (coming soon).  

## ScoutFS Metadata Backup
Script that runs a dump of the scoutfs file system metadata.  This will allow for a restore of data from tape in the event that the file system has a catastrophic failure. Data that had been staged to tape will be able to be located with the data in this dump.  

This script dumps the metadata at a pre-defined location, logs its activty, and sends a summary of metrics about the dump to an InfluxDB server

## Dashboards and Telegraf Configs
- A sample telegraf config file for the scout* input checks is in this repo as scout_telegraf.conf
- Sample dashboards are coming soon
