import boto3
import json

region = <mongodb_cluster_region>
ec2 = boto3.resource('ec2', region)
instances= ec2.meta.client.describe_instances()

def fetch_instance_details():
    """1. Fetches instances and volume details based on the tags of the replica sets in the sharded cluster.
       2. Chooses 1 node from each replica set to snapshot an EBS volume(this is choice is based on the cost vs time)
    """
    unique_tags = set()
    known_replica_sets = ['csrs', 'shard1', 'shard2']
    all_instance_details = []
    for instance in instances['Reservations']:
            all_instances = instance["Instances"]
            instance_details = {}
            for ec2_instance in all_instances:
                instance_details["volume_id"] = ec2_instance["BlockDeviceMappings"][0]["Ebs"]["VolumeId"] #TODO: Search based on the volume name
                all_tags = ec2_instance["Tags"]
                for tag in all_tags: # Sends at most 1 EBS to snapshot per replica set based on uniquness of tags
                    tagName=tag["Value"].split("-")[0]
                    if tagName in known_replica_sets:
                        if tagName not in unique_tags:
                            unique_tags.add(tag["Value"].split("-")[0])
                            snapshot_ebs_volume(instance_details, tagName)
    return None


def snapshot_ebs_volume(instance_data, tagName):
    """Snapshots an EBS volume passed from fetch_instance_details function. Tags snapshot based on the replica set name
    """
    volume_to_snapshot = instance_data["volume_id"]
    snapshot = ec2.create_snapshot(
    VolumeId=volume_to_snapshot,
    TagSpecifications=[
           {
               'ResourceType': 'snapshot',
               'Tags': [
                   {
                       'Key': 'Name',
                       'Value': tagName
                   },
               ]
           },
       ]
)   
#TODO: Include date in the snapshot tagName

def main():
     fetch_instance_details()     

if __name__ == "__main__":
    main()
