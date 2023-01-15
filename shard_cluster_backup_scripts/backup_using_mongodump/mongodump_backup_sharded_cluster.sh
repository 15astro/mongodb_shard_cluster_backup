#!/bin/bash

queryRouter=$1
backup_tag=$(date "+%d_%m_%Y")
backupUser=<backupUsername>
backupPasswd=<backupPasswd>
authDB=<authDB>
backupLocation=<backupLocation>
backupS3Bucket=<backupS3Bucket>

#3 Backup replica set member using mongodump from a secondary member
function backup_replica_set(){
  component=`echo $1 | awk -F '/' '{ print $1}'` # Get name of the replica set 
  mongodump --host $1 --username $backupUser --password $backupPasswd --authenticationDatabase $authDB --readPreference=secondary --oplog  --out $backupLocation/mongodump_$backup_tag/${component}_$backup_tag 
}

#1 Connect to mongos. Parse CSRS and shard replica sets to backup. Pass them to function backup_replica_set one by one. Stop balancer before dump
function get_cluster_components(){
  setBalancerState false
  config_replica_set=`mongo --host $queryRouter --quiet --username $backupUser --password $backupPasswd --authenticationDatabase $authDB --eval "db.getSiblingDB('admin').runCommand('getShardMap').map.config"`
  backup_replica_set $config_replica_set
  shards=(`mongo --host $queryRouter --quiet --username $backupUser --password $backupPasswd --authenticationDatabase $authDB --eval "db.getSiblingDB('config').getCollection('shards').find().forEach(function(shard){print(shard.host)})"`)
  for shard in ${shards[@]}
  do
	  backup_replica_set $shard
  done
}

#2 Helper function to start/stop balancer during and after backups
function setBalancerState(){
  mongo --quiet --host $queryRouter --username $backupUser --password $backupPasswd --authenticationDatabase $authDB --eval "sh.setBalancerState($1).ok"
}

#4 Compress and upload daily backup to s3 bucket
function upload_to_s3(){
  tar -cvzf $backupLocation/mongodump_$backup_tag.tar.gz $backupLocation/mongodump_$backup_tag
  aws s3 cp $backupLocation/mongodump_$backup_tag.tar.gz s3://$backupS3Bucket
}

get_cluster_components
setBalancerState true
upload_to_s3
