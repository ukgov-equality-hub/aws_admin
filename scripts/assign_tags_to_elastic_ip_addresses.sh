#!/bin/bash

# Script to tag Elastic IP addresses with Service and Environment tags from their associated VPC
# Region: eu-west-2

set -e  # Exit on any error

REGION="eu-west-2"

echo ""
echo "Starting Elastic IP tagging process"


# Function to check if jq is installed
check_jq() {
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is required but not installed. Please install jq to run this script."
        exit 1
    fi
}


# Function to create tags on Elastic IP
create_eip_tags() {
    local resource_id="$1"
    local service_value="$2"
    local environment_value="$3"
    
    local tags_to_create=()
    
    # Prepare tags array
    if [[ -n "$service_value" ]]; then
        tags_to_create+=("Key=Service,Value=$service_value")
    fi
    
    if [[ -n "$environment_value" ]]; then
        tags_to_create+=("Key=Environment,Value=$environment_value")
    fi
    
    if [[ ${#tags_to_create[@]} -eq 0 ]]; then
        echo "  No Service or Environment tags found on VPC to copy"
        return 0
    fi
    
    echo "  Tags to create:"
    for tag in "${tags_to_create[@]}"; do
        echo "    $tag"
    done
    
    # Create the tags
    aws ec2 create-tags \
        --region "$REGION" \
        --resources "$resource_id" \
        --tags "${tags_to_create[@]}"
    
    echo "  Tags successfully created on resource: ($resource_id)"
}


# Main function
main() {
	echo ""
	echo "Checking if jq command is present"
	check_jq
	
	echo ""
    echo "Fetching all Network Interfaces in region: ($REGION)"
	all_network_interfaces_data=$(aws ec2 describe-network-interfaces --region "$REGION" --output json)

	network_interface_ids==$(echo "$all_network_interfaces_data" | jq -r '.NetworkInterfaces[].NetworkInterfaceId')
	
	while read -r network_interface_id; do

		echo ""
		
		# Remove carriage return (\r) from network_interface_id
		network_interface_id="${network_interface_id/$'\r'/}"		
		echo "Network Interface ID: ($network_interface_id)";
		
		# Get the Network Interface data for this Network Interface ID
		network_interface_data=$(echo "$all_network_interfaces_data" | jq -r ".NetworkInterfaces[] | select(.NetworkInterfaceId == \"$network_interface_id\")")
		# echo "network_interface_data: $network_interface_data"
		
		# Check if this Network Interface already has a tag called "Service"
		service_tag=$(echo "$network_interface_data" | jq -r '.TagSet[]? | select(.Key == "Service") | .Value')
		# echo "  service_tag: $service_tag"
		
		if [[ "$service_tag" != "null" && "$service_tag" != "" ]]; then
			echo "  Skipping - Network Interface already has 'Service' tag"
			continue
		fi
		echo "  No service tag"
		
		# Get VPC ID from network interface
		vpc_id=$(echo "$network_interface_data" | jq -r '.VpcId')
        
        if [[ -z "$vpc_id" || "$vpc_id" == "null" ]]; then
            echo "  Skipping - Could not determine VPC for network interface"
            continue
        fi        
        echo "  Network Interface is in VPC: ($vpc_id)"
		
        # Get VPC details and tags
		vpc_data=$(aws ec2 describe-vpcs --region "$REGION" --vpc-ids "$vpc_id" --output json)
		# echo "  vpc_data: $vpc_data"
		
		# Extract Service and Environment tags from VPC
		service_tag=$(echo "$vpc_data" | jq -r '.Vpcs[0].Tags[]? | select(.Key == "Service") | .Value')
		environment_tag=$(echo "$vpc_data" | jq -r '.Vpcs[0].Tags[]? | select(.Key == "Environment") | .Value')
        echo "  VPC Service tag: (${service_tag:-'(not found)'})"
        echo "  VPC Environment tag: (${environment_tag:-'(not found)'})"
		
		echo "  Creating tags on Network Interface"
		create_eip_tags "$network_interface_id" "$service_tag" "$environment_tag"
		
	done <<< "$network_interface_ids"

	echo ""	
	echo "Network Interface tagging process completed!"

	echo ""
    echo "Fetching all Elastic IP addresses in region: ($REGION)"
	all_elastic_ips_data=$(aws ec2 describe-addresses --region "$REGION" --output json)
	# echo -e "all_elastic_ips_data:\n$all_elastic_ips_data"

	allocation_ids=$(echo "$all_elastic_ips_data" | jq -r '.Addresses[].AllocationId')
	# echo -e "allocation_ids:\n$allocation_ids"

	while read -r allocation_id; do

		echo ""
		
		# Remove carriage return (\r) from allocation_id
		allocation_id="${allocation_id/$'\r'/}"		
		echo "Allocation ID: ($allocation_id)";
		
		# Get the Elastic IP data for this Allocation ID
		elastic_ip_data=$(echo "$all_elastic_ips_data" | jq -r ".Addresses[] | select(.AllocationId == \"$allocation_id\")")
		# echo "elastic_ip_data: $elastic_ip_data"
		
		# Check if this Elastic IP already has a tag called "Service"
		service_tag=$(echo "$elastic_ip_data" | jq -r '.Tags[]? | select(.Key == "Service") | .Value')
		# echo "  service_tag: $service_tag"
		
		if [[ "$service_tag" != "null" && "$service_tag" != "" ]]; then
			echo "  Skipping - EIP already has 'Service' tag"
			continue
		fi
		echo "  No service tag"
		
		# Get the Network Interface ID for this Elastic IP
		network_interface_id=$(echo "$elastic_ip_data" | jq -r '.NetworkInterfaceId // empty')
		# echo "  network_interface_id: $network_interface_id"
		
		if [[ -z "$network_interface_id" || "$network_interface_id" == "null" ]]; then
            echo "  Skipping - EIP is not associated with any network interface"
            continue
        fi
		echo "  Associated with Network Interface: ($network_interface_id)"
		
		# Get the Network Interface details for this Network Interface ID
		network_interface_data=$(aws ec2 describe-network-interfaces --region "$REGION" --network-interface-ids "$network_interface_id" --output json)
		# echo "  network_interface_data: $network_interface_data"
		
		# Extract Service and Environment tags from Network Interface
		service_tag=$(echo "$network_interface_data" | jq -r '.NetworkInterfaces[0].TagSet[]? | select(.Key == "Service") | .Value')
		environment_tag=$(echo "$network_interface_data" | jq -r '.NetworkInterfaces[0].TagSet[]? | select(.Key == "Environment") | .Value')
        echo "  Network Interface Service tag: (${service_tag:-'(not found)'})"
        echo "  Network Interface Environment tag: (${environment_tag:-'(not found)'})"
		
		echo "  Creating tags on Elastic IP"
		create_eip_tags "$allocation_id" "$service_tag" "$environment_tag"
		
	done <<< "$allocation_ids"

	echo ""	
	echo "Elastic IP tagging process completed!"
}

# Run the main function
main
