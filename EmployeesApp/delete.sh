#!/bin/bash

#Delete Nat Gateways
export NGW_IDS=$(aws ec2 describe-nat-gateways --query 'NatGateways[].NatGatewayId' --output text)
for NGW_ID in $NGW_IDS; do
    echo "Deleting NAT gateway: $NGW_ID"
    aws ec2 delete-nat-gateway --nat-gateway-id $NGW_ID
done

#Delete Auto Scaling Group
export EC2_GROUP='GroupEmployeesApp'
aws autoscaling delete-auto-scaling-group --auto-scaling-group-name $EC2_GROUP --force-delete

#Delete Application Load Balancer
export LB_ARNS=$(aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerArn' --output text)

for ARN in $LB_ARNS; do
    aws elbv2 delete-load-balancer --load-balancer-arn $ARN
done

#Retrieve and delete S3 Buckets
export BUCKET_NAMES=$(aws s3api list-buckets --query 'Buckets[].Name' --output text)

for BUCKET_NAME in $BUCKET_NAMES; do
    aws s3api delete-bucket --bucket $BUCKET_NAME
done

#Retrieve and delete EC2 Instances
export INSTANCE_IDS=$(aws ec2 describe-instances --query 'Reservations[].Instances[].InstanceId' --output text)

for INSTANCE_ID in $INSTANCE_IDS; do
    echo "Terminating instance: $INSTANCE_ID"
    aws ec2 terminate-instances --instance-ids $INSTANCE_ID
done

#Retrieve and delete DynamoDBs
export TABLE_NAMES=$(aws dynamodb list-tables --query 'TableNames' --output text)

for TABLE_NAME in $TABLE_NAMES; do
    aws dynamodb delete-table --table-name $TABLE_NAME
done

#Retrieve and delete Target Groups
export TARGET_GROUP_ARNS=$(aws elbv2 describe-target-groups --query 'TargetGroups[].TargetGroupArn' --output text)
for TARGET_GROUP_ARN in $TARGET_GROUP_ARNS; do
    aws elbv2 delete-target-group --target-group-arn $TARGET_GROUP_ARN
done

#Delete Role and Instance Profile
export INSTANCE_PROFILE='EmployeesApp'
export ROLE_NAME='EmployeesApp'
export POLICY_ARN_LIST=$(aws iam list-attached-role-policies --role-name $ROLE_NAME --query 'AttachedPolicies[].PolicyArn' --output text)

for POLICY_ARN in $POLICY_ARN_LIST; do
    aws iam detach-role-policy --role-name $ROLE_NAME --policy-arn $POLICY_ARN
done

aws iam remove-role-from-instance-profile --instance-profile-name $INSTANCE_PROFILE --role-name $ROLE_NAME
aws iam delete-role --role-name $ROLE_NAME
aws iam delete-instance-profile --instance-profile-name $INSTANCE_PROFILE

#Retrieve and delete Launch Templates
export TEMPLATE_IDS=$(aws ec2 describe-launch-templates --query 'LaunchTemplates[].LaunchTemplateId' --output text)

for TEMPLATE_ID in $TEMPLATE_IDS; do
    aws ec2 delete-launch-template --launch-template-id $TEMPLATE_ID
done

#Retrieve and delete SSH Keys
export SSH_KEYS=$(aws ec2 describe-key-pairs --query 'KeyPairs[].KeyName' --output text)

for KEY_NAME in $SSH_KEYS; do
    aws ec2 delete-key-pair --key-name $KEY_NAME
done

#Retrieve VPC ID
export VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=VpcEmployeesApp" --query "Vpcs[0].VpcId" --output text)

#Delete Network Interfaces
export NETWORK_INTERFACE_IDS=$(aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=$VPC_ID" --query 'NetworkInterfaces[*].NetworkInterfaceId' --output text)

for NETWORK_INTERFACE_ID in $NETWORK_INTERFACE_IDS; do
    echo "Deleting network interface: $NETWORK_INTERFACE_ID"
    aws ec2 delete-network-interface --network-interface-id $NETWORK_INTERFACE_ID
done

#Delete security group
export EC2_SG_NAME='SgEc2EmployeesApp'
export ALB_SG_NAME='SgAlbEmployeesApp'

export EC2_SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values='$EC2_SG_NAME'" --query 'SecurityGroups[0].GroupId' --output text)
export ALB_SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values='$ALB_SG_NAME'" --query 'SecurityGroups[0].GroupId' --output text)

echo $ALB_SG_ID
echo $EC2_SG_ID

aws ec2 revoke-security-group-ingress --group-id $ALB_SG_ID  --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 revoke-security-group-ingress --group-id $EC2_SG_ID  --ip-permissions IpProtocol=tcp,FromPort=80,ToPort=80,UserIdGroupPairs='[{GroupId='$ALB_SG_ID'}]'
aws ec2 revoke-security-group-egress --group-id $ALB_SG_ID  --ip-permissions IpProtocol=tcp,FromPort=80,ToPort=80,UserIdGroupPairs='[{GroupId='$EC2_SG_ID'}]'
aws ec2 revoke-security-group-egress --group-id $EC2_SG_ID --protocol all --port all --cidr 0.0.0.0/0
aws ec2 revoke-security-group-egress --group-id $ALB_SG_ID --protocol all --port all --cidr 0.0.0.0/0
aws ec2 delete-security-group --group-id $EC2_SG_ID
aws ec2 delete-security-group --group-id $ALB_SG_ID

#Delete subnets
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[].SubnetId' --output text
export SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[].SubnetId' --output text)
for SUBNET_ID in $SUBNET_IDS; do
    aws ec2 delete-subnet --subnet-id "$SUBNET_ID"
done

#Delete Internet Gateways
aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query 'InternetGateways[].InternetGatewayId' --output text
export IGW_IDS=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query 'InternetGateways[].InternetGatewayId' --output text)
for IGW_ID in $IGW_IDS; do
    aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID"
    aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID"
done

#Delete Route Tables
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --query 'RouteTables[].RouteTableId' --output text
export RT_IDS=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --query 'RouteTables[].RouteTableId' --output text)
for RT_ID in $RT_IDS; do
    aws ec2 delete-route-table --route-table-id "$RT_ID"
done

#Delete AMIs
aws ec2 describe-images --owners self --query 'Images[].ImageId' --output text
export AMI_IDS=$(aws ec2 describe-images --owners self --query 'Images[].ImageId' --output text)
for AMI_ID in $AMI_IDS; do
    aws ec2 deregister-image --image-id "$AMI_ID"
done

#Delete Snapshots
export SNAPSHOT_IDS=$(aws ec2 describe-snapshots --owner-ids self --query 'Snapshots[].SnapshotId' --output text)
for SNAPSHOT_ID in $SNAPSHOT_IDS; do
    aws ec2 delete-snapshot --snapshot-id "$SNAPSHOT_ID"
done

#Delete Elastic IPs
export ALLOC_IDS=$(aws ec2 describe-addresses --query 'Addresses[].AllocationId' --output text)
for ALLOC_ID in $ALLOC_IDS; do
    echo "Releasing Elastic IP: $ALLOC_ID"
    aws ec2 release-address --allocation-id $ALLOC_ID
done

aws ec2 delete-vpc --vpc-id $VPC_ID

#Delete buckets
export BUCKETS_NAMES=$(aws s3api list-buckets --query 'Buckets[].Name' --output text)
for BUCKETS_NAME in $BUCKETS_NAMES; do
    echo "Deleting files..."
    aws s3 rm s3://$BUCKETS_NAME --recursive
    echo "Deleting bucket: $BUCKETS_NAME"
    aws s3api delete-bucket --bucket "$BUCKETS_NAMES"
done