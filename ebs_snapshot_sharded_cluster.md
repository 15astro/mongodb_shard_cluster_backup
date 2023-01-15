# EBS Snapshot Backup and Restore for MongoDB Sharded Cluster

Suitable for shard clusters deployed on the AWS cloud

## Prerequisites:
- Region
- Replica set names to be backed up
- Fsynclock is recommended when the data and journal are on separate mount points

## How to backup:
This backup script can be scheduled as cron on any AES EC2 instance with IAM/SSM to access EC2 metadata and EBS

## What this script does
- Uses boto3 to fetch instance details within specific region
- Chooses only 1 node from each replica set to take EBS volume snapshot
- Performs EBS volume snapshot on the selected EC2 using volume_id

## What's not covered
- Fetch EC2 instance details with multiple regions
- Copy all nodes of the replica set - cost/time to restore preposition required
- Tag EBS snapshots by date 
- Email alerting for success and failures of the backups

## High Level steps to restore shard cluster:
- Stop all applications conncting to this shard cluster while restore is going on
- Stop all components from the sharded cluster
- Remove existing data(backup is required) from all replica sets 
- For one node each from CSRS, shar1, shard2 etc where snapshot is available:
    - Create a volume from the EBS snapshot
    - Attach volume to mongod instance
    - Mount attached volume to mongodb data partition
- Start the current node as:
    - Standalone node on the different port than the port configured for replica set
    - Disable authentication to ease the restore process(optional)
- CSRS - If needs to be restored as different replica set, update config.shard entries
- Shards - Remove admin.system.version document to remove ystem.version
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





