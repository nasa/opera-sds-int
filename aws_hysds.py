#!/usr/bin/env python3

# This script is used to perform common AWS operations in a hySDS cluster:
# 1. View status of and start/stop EC2 instances
# 2. View and set the min, max, or desired capacity of Auto-Scaling Groups
# 3. View status of and enable/disable EventBridge

import argparse
import boto3

_LJ_M = 70
_LJ_F = 10

def add_prefix(parser):
    parser.add_argument("prefix", help="The prefix of the AWS resource name, e.g. opera-int-fwd, opera-pyoon-1")
    return parser

def print_non_unique_message(resource, unique_absolute_asg_names):
    print(
        "Unique %s cannot be determined. These are the %s that match the prefix and sub_name:" % (resource, resource))
    for key in unique_absolute_asg_names:
        print(key)

def take_ec2_action(ec2_name, action):
    if action == "start":
        print("Starting instance", ec2_name, instance_map[ec2_name])
        print(ec2.start_instances(InstanceIds=instance_ids))
    elif action == "stop":
        print("Stopping instance", ec2_name, instance_map[ec2_name])
        print(ec2.stop_instances(InstanceIds=instance_ids))
    else:
        print("Instance state:", ec2_name, instance_map[ec2_name]['State'])

def get_unique_resources(resource_map, prefix, sub_name):
    # Build up all the Auto-Scaling Group names that match the prefix and sub_name but have to do two passes
    absolute_asg_names = []
    for key in resource_map:
        if key.startswith(prefix) and key.find(sub_name) != -1:
            absolute_asg_names.append(key)

    # but if sub_name is exactly the string that the auto-scaling group ends with, then only that auto-scaling group is used
    # This is necessary because we have asg names that's like data_download and data_download_hist
    # But we have to be careful and not think that just "d" is a unique sub_name
    unique_absolute_asg_names = []
    for key in absolute_asg_names:
        if key[-len(sub_name):] == sub_name:
            if len(unique_absolute_asg_names) == 0:
                unique_absolute_asg_names = [key]
            else:
                unique_absolute_asg_names = absolute_asg_names
                break

    if unique_absolute_asg_names == []:
        unique_absolute_asg_names = absolute_asg_names

    return unique_absolute_asg_names

# Get two parameters from the command line using ArgumentParser: prefix and name
parser = argparse.ArgumentParser()
subparsers = parser.add_subparsers(dest="subparser_name", required=True)
server_parser = subparsers.add_parser("server", help="HySDS Server Operations")
add_prefix(server_parser)
server_parser.add_argument("name", help="The name of the instance: mozart, grq, factotum, metrics, or all", choices=["mozart", "grq", "factotum", "metrics", "all"], nargs='?', default="all")
server_parser.add_argument("action", help="start or stop the instance", choices=["start", "stop"], nargs='?')

asg_parser = subparsers.add_parser("asg", help="Auto-Scaling Group Operations")
add_prefix(asg_parser)
asg_parser.add_argument("sub_name", help="Partial string of the Auto-Scaling Group name without the prefix", nargs='?', default="")
asg_parser.add_argument("action", help="Set min, max, or desired capacity", choices=["set_min", "set_max", "set_desired"], nargs='?')
asg_parser.add_argument("value", help="The value to set the capacity to", nargs='?')

eb_parser = subparsers.add_parser("eventbridge", help="EventBridge Operations (Lambda timer triggers)")
add_prefix(eb_parser)
eb_parser.add_argument("sub_name", help="Partial string of the EventBridge name without the prefix", nargs='?', default="")
eb_parser.add_argument("action", help="Enable or disable the EventBridge trigger and therefore the lambda", choices=["enable", "disable"], nargs='?')

args = parser.parse_args()

if args.subparser_name == "server":

    ec2 = boto3.client('ec2')
    response = ec2.describe_instances()
    instance_map = {}
    for reservation in response["Reservations"]:
        for instance in reservation["Instances"]:
            for tag in instance['Tags']:
                if tag['Key'] == 'Name':
                    ec2_state = {}
                    ec2_state["InstanceId"] = instance["InstanceId"]
                    ec2_state["State"] = instance["State"]["Name"]
                    instance_map[tag['Value']] = ec2_state

    # if name is all, create a list of all InstanceIds for the prefix
    if args.name == "all":
        instance_ids = []
        for key in instance_map:
            if key.startswith(args.prefix):
                instance_ids.append(instance_map[key]["InstanceId"])
        print("Instances for prefix", args.prefix, ":", instance_ids)
        ec2_name = args.prefix + "-pcm-"

    else:
        ec2_name = args.prefix + "-pcm-" + args.name
        instance_ids = [instance_map[ec2_name]["InstanceId"]]

    if args.action in ["start", "stop"]:
        take_ec2_action(ec2_name, args.action)
    else:
        # Print the state of the machine
        if (args.name == "all"):
            print("State of all instances for prefix", args.prefix)
            for name in ["mozart", "grq", "factotum", "metrics"]:
                print("Instance state:", ec2_name + name, instance_map[ec2_name + name]['State'])
        else:
            print("Instance state:", ec2_name, instance_map[ec2_name]['State'])

elif args.subparser_name == "asg":
    # Get all Auto-Scaling Groups
    asg_client = boto3.client('autoscaling')
    paginator = asg_client.get_paginator('describe_auto_scaling_groups')
    asg_list = paginator.paginate()

    # Parse out auto-scaling groups id, name, minimum, maximum, desired capacities, and instances
    asg_map = {}
    for response in asg_list:
        for group in response["AutoScalingGroups"]:
            asg_state = {}
            asg_state["AutoScalingGroupName"] = group["AutoScalingGroupName"]
            asg_state["MinSize"] = group["MinSize"]
            asg_state["MaxSize"] = group["MaxSize"]
            asg_state["DesiredCapacity"] = group["DesiredCapacity"]
            asg_state["Instances"] = group["Instances"]
            asg_map[group["AutoScalingGroupName"]] = asg_state

    unique_absolute_asg_names = get_unique_resources(asg_map, args.prefix, args.sub_name)

    if args.action in ["set_min", "set_max", "set_desired"]:
        if len(unique_absolute_asg_names) != 1:
            print_non_unique_message("Auto-Scaling Group", unique_absolute_asg_names)
        else:
            if args.action == "set_min":
                print("Setting min size for Auto-Scaling Group")
                print(asg_client.update_auto_scaling_group(AutoScalingGroupName=unique_absolute_asg_names[0], MinSize=int(args.value)))

            if args.action == "set_max":
                print("Setting max size for Auto-Scaling Group")
                print(asg_client.update_auto_scaling_group(AutoScalingGroupName=unique_absolute_asg_names[0], MaxSize=int(args.value)))

            if args.action == "set_desired":
                print("Setting desired size for Auto-Scaling Group")
                print(asg_client.update_auto_scaling_group(AutoScalingGroupName=unique_absolute_asg_names[0], DesiredCapacity=int(args.value)))
    else:
        # Print out the auto-scaling groups
        print("AutoScalingingGroupName".ljust(_LJ_M), "MinSize".ljust(_LJ_F), "MaxSize".ljust(_LJ_F), "Desired".ljust(_LJ_F), "Instances")
        for key in unique_absolute_asg_names:
            a = asg_map[key]
            print(a["AutoScalingGroupName"].ljust(_LJ_M), str(a["MinSize"]).ljust(_LJ_F), str(a["MaxSize"]).ljust(_LJ_F),
                  str(a["DesiredCapacity"]).ljust(_LJ_F), len(a["Instances"]))


elif args.subparser_name == "eventbridge":
    # Get all EventBridge rules
    eb_client = boto3.client('events')
    paginator = eb_client.get_paginator('list_rules')
    eb_list = paginator.paginate()

    # Parse out eventbridge rules
    eb_map = {}
    for response in eb_list:
        for rule in response["Rules"]:
            eb_state = {}
            eb_state["Name"] = rule["Name"]
            eb_state["State"] = rule["State"]
            eb_map[rule["Name"]] = eb_state

    unique_absolute_eb_names = get_unique_resources(eb_map, args.prefix, args.sub_name)

    if args.action in ["enable", "disable"]:
        if len(unique_absolute_eb_names) != 1:
            print_non_unique_message("EventBridge", unique_absolute_eb_names)
        else:
            if args.action == "enable":
                print("Enabling EventBridge rule")
                print(eb_client.enable_rule(Name=unique_absolute_eb_names[0]))

            if args.action == "disable":
                print("Disabling EventBridge rule")
                print(eb_client.disable_rule(Name=unique_absolute_eb_names[0]))
    else:
        # Print out the eventbridge rules
        print("EventBridge Rule".ljust(_LJ_M), "State")
        for key in unique_absolute_eb_names:
            e = eb_map[key]
            print(e["Name"].ljust(_LJ_M), e["State"])