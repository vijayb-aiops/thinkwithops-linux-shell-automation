#!/bin/bash

# ==============================
# CONFIGURATION
# ==============================
REGION="us-east-1"
AMI_ID="ami-04b70fa74e45c3917"   # Ubuntu 22.04 LTS (x86_64, us-east-1)
INSTANCE_TYPE="t3.micro"         # ✅ Free tier eligible
KEY_NAME="my-key-pair"
SECURITY_GROUP="my-sg"
KEY_FILE="$HOME/$KEY_NAME.pem"

echo "==========================================="
echo "   🚀 AWS EC2 Free Tier Ubuntu Launcher"
echo "==========================================="

# ==============================
# CREATE OR REUSE KEY PAIR
# ==============================
echo "🔑 Checking key pair..."
if ! aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region $REGION >/dev/null 2>&1; then
    echo "📦 Creating new key pair '$KEY_NAME'..."
    aws ec2 create-key-pair \
        --region $REGION \
        --key-name $KEY_NAME \
        --query 'KeyMaterial' \
        --output text > "$KEY_FILE"
    chmod 400 "$KEY_FILE"
    echo "✅ Key pair saved to $KEY_FILE"
else
    echo "⚠️ Key pair '$KEY_NAME' already exists. Reusing it."
fi

# ==============================
# CREATE OR REUSE SECURITY GROUP
# ==============================
echo "🔒 Checking security group..."
SG_ID=$(aws ec2 describe-security-groups \
    --region $REGION \
    --group-names $SECURITY_GROUP \
    --query 'SecurityGroups[0].GroupId' \
    --output text 2>/dev/null)

if [ -z "$SG_ID" ] || [ "$SG_ID" == "None" ]; then
    echo "📦 Creating new security group '$SECURITY_GROUP'..."
    SG_ID=$(aws ec2 create-security-group \
        --region $REGION \
        --group-name $SECURITY_GROUP \
        --description "Allow SSH from my IP" \
        --query 'GroupId' \
        --output text)

    MY_IP=$(curl -s https://checkip.amazonaws.com)
    echo "🌐 Authorizing SSH from your IP ($MY_IP)..."
    aws ec2 authorize-security-group-ingress \
        --region $REGION \
        --group-id $SG_ID \
        --protocol tcp \
        --port 22 \
        --cidr ${MY_IP}/32
else
    echo "⚠️ Security group '$SECURITY_GROUP' already exists (ID: $SG_ID). Reusing it."
fi

# ==============================
# LAUNCH INSTANCE
# ==============================
echo "🚀 Launching Ubuntu EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
    --region $REGION \
    --image-id $AMI_ID \
    --count 1 \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SG_ID \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=Ubuntu-FreeTier}]" \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "⏳ Waiting for instance ($INSTANCE_ID) to be running..."
aws ec2 wait instance-running --region $REGION --instance-ids $INSTANCE_ID

PUBLIC_IP=$(aws ec2 describe-instances \
    --region $REGION \
    --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

echo "==========================================="
echo "✅ Ubuntu EC2 Instance Created Successfully!"
echo "   Instance ID : $INSTANCE_ID"
echo "   Public IP   : $PUBLIC_IP"
echo "   Key File    : $KEY_FILE"
echo "==========================================="
echo ""
echo "🔑 Connect using:"
echo "ssh -i \"$KEY_FILE\" ubuntu@$PUBLIC_IP"
