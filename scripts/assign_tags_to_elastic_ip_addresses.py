import boto3
import os

REGION = os.environ.get("AWS_REGION", "eu-west-2")
SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]

ec2 = boto3.client("ec2", region_name=REGION)
sns = boto3.client("sns", region_name=REGION)


def get_tag(tags, key):
    """Return the value of a tag by key, or None if not found."""
    for tag in tags or []:
        if tag["Key"] == key:
            return tag["Value"]
    return None


def create_eip_tags(resource_id, service_value, environment_value):
    """Apply Service and/or Environment tags to a resource."""
    tags = []
    if service_value:
        tags.append({"Key": "Service", "Value": service_value})
    if environment_value:
        tags.append({"Key": "Environment", "Value": environment_value})

    if not tags:
        print("  No Service or Environment tags found on VPC to copy")
        return

    for tag in tags:
        print(f"    {tag['Key']}={tag['Value']}")

    ec2.create_tags(Resources=[resource_id], Tags=tags)
    print(f"  Tags successfully created on resource: ({resource_id})")


def tag_network_interfaces():
    """Tag all Network Interfaces with Service/Environment from their VPC."""
    print()
    print(f"Fetching all Network Interfaces in region: ({REGION})")
    response = ec2.describe_network_interfaces()
    all_enis = response["NetworkInterfaces"]

    # Cache VPC tag lookups to avoid repeated API calls
    vpc_tag_cache = {}

    for eni in all_enis:
        eni_id = eni["NetworkInterfaceId"]
        print()
        print(f"Network Interface ID: ({eni_id})")

        # Skip if already tagged with Service
        existing_service = get_tag(eni.get("TagSet", []), "Service")
        if existing_service:
            print("  Skipping - Network Interface already has 'Service' tag")
            continue
        print("  No service tag")

        # Get VPC ID
        vpc_id = eni.get("VpcId")
        if not vpc_id:
            print("  Skipping - Could not determine VPC for network interface")
            continue
        print(f"  Network Interface is in VPC: ({vpc_id})")

        # Fetch VPC tags (cached)
        if vpc_id not in vpc_tag_cache:
            vpc_response = ec2.describe_vpcs(VpcIds=[vpc_id])
            vpcs = vpc_response.get("Vpcs", [])
            vpc_tags = vpcs[0].get("Tags", []) if vpcs else []
            vpc_tag_cache[vpc_id] = vpc_tags

        vpc_tags = vpc_tag_cache[vpc_id]
        service_tag = get_tag(vpc_tags, "Service")
        environment_tag = get_tag(vpc_tags, "Environment")
        print(f"  VPC Service tag: ({service_tag or '(not found)'})")
        print(f"  VPC Environment tag: ({environment_tag or '(not found)'})")

        print("  Creating tags on Network Interface")
        create_eip_tags(eni_id, service_tag, environment_tag)

    print()
    print("Network Interface tagging process completed!")


def tag_elastic_ips():
    """Tag all Elastic IPs with Service/Environment from their associated Network Interface."""
    print()
    print(f"Fetching all Elastic IP addresses in region: ({REGION})")
    response = ec2.describe_addresses()
    all_eips = response["Addresses"]

    for eip in all_eips:
        allocation_id = eip["AllocationId"]
        print()
        print(f"Allocation ID: ({allocation_id})")

        # Skip if already tagged with Service
        existing_service = get_tag(eip.get("Tags", []), "Service")
        if existing_service:
            print("  Skipping - EIP already has 'Service' tag")
            continue
        print("  No service tag")

        # Get associated Network Interface ID
        eni_id = eip.get("NetworkInterfaceId")
        if not eni_id:
            print("  Skipping - EIP is not associated with any network interface")
            continue
        print(f"  Associated with Network Interface: ({eni_id})")

        # Fetch Network Interface tags
        eni_response = ec2.describe_network_interfaces(NetworkInterfaceIds=[eni_id])
        enis = eni_response.get("NetworkInterfaces", [])
        eni_tags = enis[0].get("TagSet", []) if enis else []

        service_tag = get_tag(eni_tags, "Service")
        environment_tag = get_tag(eni_tags, "Environment")
        print(f"  Network Interface Service tag: ({service_tag or '(not found)'})")
        print(f"  Network Interface Environment tag: ({environment_tag or '(not found)'})")

        print("  Creating tags on Elastic IP")
        create_eip_tags(allocation_id, service_tag, environment_tag)

    print()
    print("Elastic IP tagging process completed!")


def handler(event, context):
    """Lambda entry point."""
    print()
    print("Starting Elastic IP tagging process")

    try:
        tag_network_interfaces()
        tag_elastic_ips()

        print()
        print("All tagging completed successfully.")

        # Collect a summary for the email
        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject="[SUCCESS] Daily Elastic IP tagging script ran successfully",
            Message=(
                "Your daily Elastic IP tagging script completed successfully.\n\n"
                "Check CloudWatch Logs for the full output:\n"
                f"  Log group: https://eu-west-2.console.aws.amazon.com/cloudwatch/home?region=eu-west-2#logsV2:log-groups/log-group/$252Faws$252Flambda$252Faws-admin--tag-ips--function\n"
            )
        )

    except Exception as e:
        error_message = str(e)
        print(f"Script failed: {error_message}")

        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject="[FAILED] Daily Elastic IP tagging script failed",
            Message=(
                f"Your daily Elastic IP tagging script failed with the following error:\n\n"
                f"{error_message}\n\n"
                f"Check CloudWatch Logs for the full output:\n"
                f"  Log group: https://eu-west-2.console.aws.amazon.com/cloudwatch/home?region=eu-west-2#logsV2:log-groups/log-group/$252Faws$252Flambda$252Faws-admin--tag-ips--function\n"
            )
        )
        raise
