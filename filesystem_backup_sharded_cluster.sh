#!/bin/bash

queryRouter=$1
backup_tag=$(date "+%d_%m_%Y")
backupUser=<backupUser>
backupPasswd=<backupPasswd>
authDB=<authDB>
backupLocation=<backupLocation>
backupS3Bucket=<backupS3Bucket>
dbPath=/mongodb/data
scpUser=<scpUser>

#3 Backup underlying data files from replica set member. Perform db.fsyncLock and unlock
function backup_replica_set(){
  mongo --quiet  --host $1 --username $backupUser --password $backupPasswd --authenticationDatabase $authDB --eval "db.fsyncLock()"
  host=`echo $1 | awk -F ':' '{ print $1}'`
  mkdir -p $backupLocation/filesystemDump_$backup_tag/${replica_set_name}_$backup_tag;scp -r $scpUser@$host:$dbPath $backupLocation/filesystemDump_$backup_tag/$2_$backup_tag/ 
  mongo --quiet --host $1 --username $backupUser --password $backupPasswd --authenticationDatabase $authDB --eval "db.fsyncUnlock()"
}

#1 Connect to mongos. Parse healthy secodary member to backup from CSRS and shard replica sets. Pass them to function backup_replica_set one by one. Stop balancer before dump
function get_cluster_components(){
  setBalancerState false
  config_replica_set=`mongo --host $queryRouter  --quiet --username $backupUser --password $backupPasswd --authenticationDatabase $authDB --eval "db.getSiblingDB('admin').runCommand('getShardMap').map.config"`
  all_replica_sets=(`mongo --host $queryRouter --quiet --username $backupUser --password $backupPasswd --authenticationDatabase $authDB --eval "db.getSiblingDB('config').getCollection('shards').find().forEach(function(shard){print(shard.host)})"`)
  all_replica_sets+=($config_replica_set)
  for replica_set in ${all_replica_sets[@]}
  do
	  replica_set_members=(`echo $replica_set | awk -F '/' '{ print $2}' | awk -F ',' '{ print $1 " " $2}'`)
	  replica_set_name=`echo $replica_set | awk -F '/' '{ print $1}'`
	  for replica_set_member in ${replica_set_members[@]}
	  	do
			is_healthy_secondary=`mongo --host $replica_set_member --quiet --username $backupUser --password $backupPasswd --authenticationDatabase $authDB --eval "rs.isMaster().secondary"`
			if [ $is_healthy_secondary = true ]
				then 
					backup_replica_set $replica_set_member $replica_set_name
                    break
				fi	
		done
  done
}

#2 Helper function to start/stop balancer during and after backups
function setBalancerState(){
  mongo --quiet --host $queryRouter --quiet --username $backupUser --password $backupPasswd --authenticationDatabase $authDB --eval "sh.setBalancerState($1).ok"
}

#4 Compress and upload daily backup to s3 bucket
function upload_to_s3(){
  tar -cvzf $backupLocation/mongodump_$backup_tag.tar.gz $backupLocation/filesystemDump_$backup_tag
  aws s3 cp $backupLocation/mongodump_$backup_tag.tar.gz s3://$backupS3Bucket
}

get_cluster_components
setBalancerState true
upload_to_s3
