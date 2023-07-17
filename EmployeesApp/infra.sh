#!/bin/bash

#Variables
export BKT_NAME='<BUCKET_NAME>'
export LOCATION='<AWS_REGION>'
export EC2_SG_NAME='SgEc2EmployeesApp'
export ALB_SG_NAME='SgAlbEmployeesApp'
export EC2_GROUP='GroupEmployeesApp'
export AZ1='sa-east-1a'
export AZ2='sa-east-1c'
export ALB_NAME='AlbEmployeesApp'
export VPC_NAME='VpcEmployeesApp'
export PUB_RT1_NAME='PubRt1EmployeesApp'
export PRIV_RT1_NAME='PrivRt1EmployeesApp'
export PRIV_RT2_NAME='PrivRt2EmployeesApp'
export IGW_NAME='IgwEmployees'
export PUB_SNET1_NAME='PubSnet1EmployeesApp'
export PUB_SNET2_NAME='PubSnet2EmployeesApp'
export PUB_SNET1_PREFIX='10.1.1.0/24'
export PUB_SNET2_PREFIX='10.1.2.0/24'
export PRIV_SNET1_NAME='PrivSnet1EmployeesApp'
export PRIV_SNET2_NAME='PrivSnet2EmployeesApp'
export PRIV_SNET1_PREFIX='10.1.3.0/24'
export PRIV_SNET2_PREFIX='10.1.4.0/24'
export TRG_GRP='TrgEmployeesApp'
export AMI_ID='ami-0555c5c3b52744258'
export TYPE='t2.micro'
export SSH_KEY_NAME='SshKeyEmployeesApp'
export TEMPLATE_NAME='TmpEmployeesApp'
export ROLE_NAME='EmployeesApp'
export TABLE_NAME='Employees'
export INSTANCE_PROFILE='EmployeesApp'
export INSTANCE_NAME='Ec2EmployeesApp'
export POLICY1_ARN='arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess'
export POLICY2_ARN='arn:aws:iam::aws:policy/AmazonS3FullAccess'

#Create Budget Alert
curl -LO https://raw.githubusercontent.com/marcioscunha/aws_labs/main/EmployeesApp/budget.json
curl -LO https://raw.githubusercontent.com/marcioscunha/aws_labs/main/EmployeesApp/notifications.json

export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws budgets create-budget --account-id $ACCOUNT_ID --budget file://budget.json --notifications-with-subscribers file://notifications.json

#Create AWS VPC and subnets
export VPC_ID=$(aws ec2 create-vpc --cidr-block $VPC_ADDRESS --tag-specification 'ResourceType=vpc,Tags=[{Key=Name,Value='$VPC_NAME'}]' --query 'Vpc.VpcId' --output text)
export PUB_SNET1_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $PUB_SNET1_PREFIX --availability-zone $AZ1 --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value='$PUB_SNET1_NAME'}]' --query 'Subnet.SubnetId' --output text)
export PUB_SNET2_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $PUB_SNET2_PREFIX --availability-zone $AZ2 --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value='$PUB_SNET2_NAME'}]' --query 'Subnet.SubnetId' --output text)
export PRIV_SNET1_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $PRIV_SNET1_PREFIX --availability-zone $AZ1 --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value='$PRIV_SNET1_NAME'}]' --query 'Subnet.SubnetId' --output text)
export PRIV_SNET2_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $PRIV_SNET2_PREFIX --availability-zone $AZ2 --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value='$PRIV_SNET2_NAME'}]' --query 'Subnet.SubnetId' --output text)


#Create Internet Gateway
export IGW_ID=$(aws ec2 create-internet-gateway --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value='$IGW_NAME'}]' --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID

#Create Natgateway
export ALLOC1_ID=$(aws ec2 allocate-address --query AllocationId --output text)
export ALLOC2_ID=$(aws ec2 allocate-address --query AllocationId --output text)
export NGW1_ID=$(aws ec2 create-nat-gateway --subnet-id $PUB_SNET1_ID --allocation-id $ALLOC1_ID --query NatGateway.NatGatewayId --output text)
export NGW2_ID=$(aws ec2 create-nat-gateway --subnet-id $PUB_SNET2_ID --allocation-id $ALLOC2_ID --query NatGateway.NatGatewayId --output text)
sleep 150

#Create Route Table
export PUB_RT1_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value='$PUB_RT_NAME'}]' --query 'RouteTable.RouteTableId' --output text)
export PRIV_RT1_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value='$PRIV_RT1_NAME'}]' --query 'RouteTable.RouteTableId' --output text)
export PRIV_RT2_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value='$PRIV_RT2_NAME'}]' --query 'RouteTable.RouteTableId' --output text)

aws ec2 associate-route-table --subnet-id $PUB_SNET1_ID --route-table-id $PUB_RT1_ID
aws ec2 associate-route-table --subnet-id $PUB_SNET2_ID --route-table-id $PUB_RT1_ID
aws ec2 associate-route-table --subnet-id $PRIV_SNET1_ID --route-table-id $PRIV_RT1_ID
aws ec2 associate-route-table --subnet-id $PRIV_SNET2_ID --route-table-id $PRIV_RT2_ID
aws ec2 create-route --route-table-id $PUB_RT1_ID --destination-cidr-block "0.0.0.0/0" --gateway-id $IGW_ID
aws ec2 create-route --route-table-id $PRIV_RT1_ID --destination-cidr-block "0.0.0.0/0" --gateway-id $NGW1_ID
aws ec2 create-route --route-table-id $PRIV_RT2_ID --destination-cidr-block "0.0.0.0/0" --gateway-id $NGW2_ID


#Create Security Group and rules
export EC2_SG_ID=$(aws ec2 create-security-group --group-name $EC2_SG_NAME --description "AllowHttpAlb" --vpc-id $VPC_ID --query 'GroupId' --output text)
export ALB_SG_ID=$(aws ec2 create-security-group --group-name $ALB_SG_NAME --description "AllowHttInternet" --vpc-id $VPC_ID --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id $ALB_SG_ID --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Name,Value=AllowHttpIn}]' --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-egress --group-id $ALB_SG_ID --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Name,Value=AllowHttpOut}]' --ip-permissions IpProtocol=tcp,FromPort=80,ToPort=80,UserIdGroupPairs='[{GroupId='$EC2_SG_ID'}]'
aws ec2 authorize-security-group-ingress --group-id $EC2_SG_ID --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Name,Value=AllowHttpIn}]' --protocol tcp --port 80 --source-group $ALB_SG_ID

#Create IAM Role and attach policies
curl -LO https://raw.githubusercontent.com/marcioscunha/aws_labs/main/EmployeesApp/trust-policy.json
aws iam create-role --role-name $ROLE_NAME --assume-role-policy-document file://trust-policy.json
aws iam attach-role-policy --role-name $ROLE_NAME  --policy-arn "$POLICY1_ARN"
aws iam attach-role-policy --role-name $ROLE_NAME  --policy-arn "$POLICY2_ARN"

#Create S3 Bucket and Bucket policy
curl -LO https://raw.githubusercontent.com/marcioscunha/aws_labs/main/EmployeesApp/s3_policy.json
aws s3api create-bucket --bucket $BKT_NAME --region $LOCATION  --create-bucket-configuration LocationConstraint=$LOCATION
aws s3api put-bucket-policy --bucket $BKT_NAME --policy file://s3_policy.json

#Create DynamoDB
aws dynamodb create-table --table-name $TABLE_NAME --attribute-definitions AttributeName=id,AttributeType=S --key-schema AttributeName=id,KeyType=HASH --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5


#Create Instance Profile and add role
aws iam create-instance-profile --instance-profile-name $INSTANCE_PROFILE
aws iam add-role-to-instance-profile --instance-profile-name $INSTANCE_PROFILE --role-name $ROLE_NAME
sleep 10

#Create EC2 Instance
curl -LO https://raw.githubusercontent.com/marcioscunha/aws_labs/main/EmployeesApp/user-data.txt
export SSH_KEY=$(aws ec2 create-key-pair --key-name $SSH_KEY_NAME --query 'KeyMaterial' --output text > Employees.pem)
export INSTANCE_ID=$(aws ec2 run-instances --image-id $AMI_ID --instance-type $TYPE --key-name $SSH_KEY_NAME --security-group-ids $EC2_SG_ID --subnet-id $PRIV_SNET1_ID --iam-instance-profile Name=$INSTANCE_PROFILE --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value='$INSTANCE_NAME'}]' --user-data "$(cat user-data.txt)" --associate-public-ip-address --query 'Instances[].InstanceId' --output text)
sleep 180
aws ec2 stop-instances --instance-ids $INSTANCE_ID
sleep 60

#Create AMI
export IMAGE_ID=$(aws ec2 create-image --instance-id $INSTANCE_ID --name $TEMPLATE_NAME --description "AMI Employee App v1" --query 'ImageId' --output text)
sleep 220

#Create Launch Template
aws ec2 create-launch-template --launch-template-name $TEMPLATE_NAME --version-description "Launch template Employee App v1" --launch-template-data '{"ImageId":"'"$IMAGE_ID"'","InstanceType":"'"$TYPE"'","SecurityGroupIds":["'"$EC2_SG_ID"'"],"IamInstanceProfile":{"Name":"'"$INSTANCE_PROFILE"'"}}'

#Create Auto Scaling Group
aws autoscaling create-auto-scaling-group --auto-scaling-group-name $EC2_GROUP --launch-template "LaunchTemplateName=$TEMPLATE_NAME" --min-size 1 --max-size 3 --desired-capacity 2 --availability-zones $AZ1 $AZ2 --vpc-zone-identifier $PRIV_SNET1_ID,$PRIV_SNET2_ID --tags Key=Name,Value=Employees

#Create Load Balancer
export ALB_ARN=$(aws elbv2 create-load-balancer --name $ALB_NAME --subnets $PUB_SNET1_ID $PUB_SNET2_ID --security-groups $ALB_SG_ID --query 'LoadBalancers[0].LoadBalancerArn' --output text)
export ALB_ARN=$(aws elbv2 describe-load-balancers --names $ALB_NAME --query 'LoadBalancers[0].LoadBalancerArn' --output text)

#Create a Target Group
export TRG_ARN=$(aws elbv2 create-target-group --name $TRG_GRP --protocol HTTP --port 80 --vpc-id $VPC_ID --ip-address-type ipv4 --query 'TargetGroups[].TargetGroupArn' --output text)
aws autoscaling attach-load-balancer-target-groups --auto-scaling-group-name $EC2_GROUP --target-group-arns $TRG_ARN

#Create ELB listener
aws elbv2 create-listener --load-balancer-arn $ALB_ARN --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn=$TRG_ARN

#Retrieve ELB FQDN
sleep 180
aws elbv2 describe-load-balancers --names $ALB_NAME --query 'LoadBalancers[].DNSName' --output text

#Retrieve instances ID
export INSTANCE_IDS=$(aws ec2 describe-instances --query 'Reservations[].Instances[].InstanceId' --output text)

for INSTANCE_ID in $INSTANCE_IDS; do
    echo "Instance ID: $INSTANCE_ID"
done