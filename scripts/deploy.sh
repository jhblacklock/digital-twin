#!/bin/bash
set -e

ENVIRONMENT=${1:-dev}          # dev | test | prod
PROJECT_NAME=${2:-twin}

echo "🚀 Deploying ${PROJECT_NAME} to ${ENVIRONMENT}..."

# 0. Check and refresh AWS SSO credentials if needed
AWS_PROFILE="jackson"
export AWS_PROFILE

echo "🔐 Checking AWS credentials (profile: $AWS_PROFILE)..."
if ! aws sts get-caller-identity --profile "$AWS_PROFILE" &>/dev/null; then
    echo "⚠️  AWS credentials not valid. Attempting SSO login..."
    echo "📝 Logging in with profile: $AWS_PROFILE"
    aws sso login --profile "$AWS_PROFILE" || {
        echo "❌ SSO login failed. Please run 'aws sso login --profile jackson' manually."
        exit 1
    }
else
    echo "✅ AWS credentials are valid"
fi

# 1. Build Lambda package
cd "$(dirname "$0")/.."        # project root
echo "📦 Building Lambda package..."
(cd backend && uv run deploy.py)

# 2. Terraform workspace & apply
cd terraform

# Get AWS Account ID and region for backend configuration
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query Account --output text)
AWS_REGION=${DEFAULT_AWS_REGION:-us-east-1}

# Detect the actual bucket region (bucket might be in a different region)
BUCKET_NAME="twin-terraform-state-${AWS_ACCOUNT_ID}"
BUCKET_REGION=$(aws s3api get-bucket-location --profile "$AWS_PROFILE" --bucket "$BUCKET_NAME" --query LocationConstraint --output text 2>/dev/null || echo "$AWS_REGION")

# Handle 'None' response (us-east-1 returns None instead of the region name)
if [ "$BUCKET_REGION" = "None" ] || [ -z "$BUCKET_REGION" ]; then
  BUCKET_REGION="us-east-1"
fi

echo "🔧 Initializing Terraform with S3 backend..."
echo "   Bucket: $BUCKET_NAME"
echo "   Region: $BUCKET_REGION"
terraform init -input=false \
  -backend-config="bucket=${BUCKET_NAME}" \
  -backend-config="key=${ENVIRONMENT}/terraform.tfstate" \
  -backend-config="region=${BUCKET_REGION}" \
  -backend-config="dynamodb_table=twin-terraform-locks" \
  -backend-config="encrypt=true"

if ! terraform workspace list | grep -q "$ENVIRONMENT"; then
  terraform workspace new "$ENVIRONMENT"
else
  terraform workspace select "$ENVIRONMENT"
fi

# Use prod.tfvars for production environment
if [ "$ENVIRONMENT" = "prod" ]; then
  TF_APPLY_CMD=(terraform apply -var-file=prod.tfvars -var="project_name=$PROJECT_NAME" -var="environment=$ENVIRONMENT" -auto-approve)
else
  TF_APPLY_CMD=(terraform apply -var="project_name=$PROJECT_NAME" -var="environment=$ENVIRONMENT" -auto-approve)
fi

echo "🎯 Applying Terraform..."
"${TF_APPLY_CMD[@]}"

API_URL=$(terraform output -raw api_gateway_url)
FRONTEND_BUCKET=$(terraform output -raw s3_frontend_bucket)
CUSTOM_URL=$(terraform output -raw custom_domain_url 2>/dev/null || true)

# 3. Build + deploy frontend
cd ../frontend

# Create production environment file with API URL
echo "📝 Setting API URL for production..."
echo "NEXT_PUBLIC_API_URL=$API_URL" > .env.production

npm install
npm run build
aws s3 sync ./out "s3://$FRONTEND_BUCKET/" --delete --profile "$AWS_PROFILE"
cd ..

# 4. Final messages
echo -e "\n✅ Deployment complete!"
echo "🌐 CloudFront URL : $(terraform -chdir=terraform output -raw cloudfront_url)"
if [ -n "$CUSTOM_URL" ]; then
  echo "🔗 Custom domain  : $CUSTOM_URL"
fi
echo "📡 API Gateway    : $API_URL"