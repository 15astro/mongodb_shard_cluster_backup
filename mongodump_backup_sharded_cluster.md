# Backup and Restore MongoDB Sharded Cluster using mongodump and mogorestore


Suitable for shard cluster with smalle data sizes. MongoDB version earlier than 4.2

### Prerequisites:
- A sharded cluster to backup
- A backup server provisioned with storage to store snapshots of CSRS and shards
- Connctivity on port 27017 from backup server to mongodb shard components

### How to backup:
This backup script accepts one argument from command line - running mongos in the format: host:port
`bash mongodump_backup_sharded_cluster 172.31.8.189:27017`

### What this script does
- Connects to mongos provided as a command line argument
- Parses metadata such as config server and shard node's endpoint
- Stops the balancer before mongodump
- Performs dump of the replica set using mongodump by using readPreference=secondary with current date tags
- Backs up the oplog while mongodump is running
- Starts the balancer after mongodump
- Compresses daily snapshot and uploads to s3

### What's not covered
- Retry conncetivity failures to mongos
- Logging of the backup events
- Does not verify replication lag on the CSRS before initiating a mongodump
- Disk size checks before on central backup server
- Email alerting for success and failures of the backups

### Why remote backups on the backup server
- Does not need to perform compression and s3 upload on the mongo servers
- Retention & removal of the dumps can be managed at the central location

### High Level steps to restore shard cluster:
- Stop all applications conncting to this shard cluster while restore is going on
- Stop all components from the sharded cluster
- Download the mongodumps to one member each from CSRS and shards or to the cental backup server
- Remove existing data(backup is required) from all replica sets 
- Start one node from each replica set - CSRS, shard1, shard2 etc as:
    - Standalone node on the different port than the port configured for replica set
    - Disable authentication to ease the restore process(optional)
- Use mongorestore with --oplogReplay to restore dump
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





