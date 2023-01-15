# Backup and Restore MongoDB Sharded Cluster using filesystem

Suitable for shard cluster with large data sizes for on-prem servers where volume snapshot feature is not available.

## Prerequisites:
- A sharded cluster to backup
- A backup server provisioned with storage to store snapshots of CSRS and shards
- Connctivity on port 27017 from backup server to mongodb shard components
- Passwordless ssh for mongodb user from backup server to all nodes in the mongo shard
- Fsynclock is recommended when the data and journal are on separate mount points

## How to backup:
This backup script accepts one argument from command line - running mongos in the format: host:port
`bash filesystem_backup_sharded_cluster 172.31.8.189:27017`

## What this script does
- Connects to mongos provided as a command line argument
- Parses metadata such as config server and shard node's endpoint
- Finds a helthy secondary to backup from
- Performs db.fysncLock on secondary node to maintain consistency of the backup
- Copies undelying data files from each node to the central backup server
- Unlocks the secondary node once the copy operation is done
- Compresses daily snapshot and uploads to s3

## What's not covered
- Retry conncetivity failures to mongos
- Logging of the backup events
- Does not verify replication lag on the CSRS before initiating copy 
- Disk size checks before on central backup server
- Email alerting for success and failures of the backups

## Why remote backups on the backup server
- Does not need to perform compression and s3 upload on the mongo servers
- Retention & removal of the dumps can be managed at the central location

## High Level steps to restore shard cluster:
- Stop all applications conncting to this shard cluster while restore is going on
- Stop all components from the sharded cluster
- Download the snapshots to one member each from CSRS and shards or to the cental backup server from s3
- Remove existing data(backup is required) from all replica sets 
- Copy data files from snapshot to dbpath of current mongod node to one node from each replica set - CSRS, shard1, shard2 etc
- Start the current node as:
    - Standalone node on the different port than the port configured for replica set
    - Disable authentication to ease the restore process(optional)
- CSRS - If needs to be restored as different replica set, update config.shard entries
- Shards - Remove admin.system.version doc to remove ystem.version
- Shards - Update config server replica set from shard identity document from each each if restoring to the different cluster
- Drop local db
- Start mongod with replication enabled
- Initiate a replica set
- Add other members of the replica set
- Follow same set of steps for config replica set, shard1, shard2 etc
- When initial sync is completed, perform a rolling restart to enable authentication
- Restart all mongos
- Validations: Login to mongos and verify sh.status(), size of databases and counts from the collections 
- Start applications and perform smoke tests





