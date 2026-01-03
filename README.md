# AI Digital Twin

An AI-powered digital twin application that creates a conversational AI representation of yourself. Built with AWS Bedrock, FastAPI, Next.js, and deployed on AWS infrastructure.

## 🎯 Overview

This application creates an AI digital twin that can engage in conversations about you, representing your professional background, experience, and communication style. The AI is powered by Amazon Bedrock's Nova models and maintains conversation memory across sessions.

## 🏗️ Architecture

- **Frontend**: Next.js 16 with React 19, TypeScript, and Tailwind CSS
- **Backend**: FastAPI deployed as AWS Lambda function
- **AI Model**: Amazon Bedrock (Nova Micro/Lite/Pro)
- **Storage**: S3 for conversation memory and static site hosting
- **CDN**: CloudFront for global content delivery
- **API**: API Gateway (HTTP API)
- **Infrastructure**: Terraform for IaC
- **CI/CD**: GitHub Actions with OIDC authentication

## 📋 Prerequisites

- Python 3.12+
- Node.js 20+
- AWS CLI configured with SSO profile
- Terraform >= 1.0
- Docker (for Lambda package building)
- AWS Account with:
  - Bedrock model access (Nova models)
  - Appropriate IAM permissions
  - S3, Lambda, API Gateway, CloudFront access

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone <repository-url>
cd twin-ai
```

### 2. Configure Backend

1. Update personal data in `backend/data/`:
   - `facts.json` - Basic information about you
   - `summary.txt` - Personal summary
   - `style.txt` - Communication style
   - `linkedin.pdf` - LinkedIn profile PDF

2. Set up environment variables:
   ```bash
   cd backend
   cp .env.example .env  # If exists
   ```

3. Install Python dependencies:
   ```bash
   cd backend
   uv sync  # or pip install -r requirements.txt
   ```

### 3. Configure Frontend

1. Install dependencies:
   ```bash
   cd frontend
   npm install
   ```

2. Set API URL (for production):
   ```bash
   echo "NEXT_PUBLIC_API_URL=https://your-api-gateway-url" > .env.production
   ```

### 4. Local Development

**Backend:**
```bash
cd backend
uvicorn server:app --reload --port 8000
```

**Frontend:**
```bash
cd frontend
npm run dev
```

Visit `http://localhost:3000` to interact with your digital twin.

## 🌐 AWS Deployment

### Initial Setup

1. **Configure AWS SSO:**
   ```bash
   aws configure sso
   # Follow prompts to set up your profile (e.g., "jackson")
   aws sso login --profile jackson
   ```

2. **Create Terraform Backend Resources:**
   ```bash
   cd terraform
   terraform init
   terraform workspace select default
   terraform apply -target=aws_s3_bucket.terraform_state \
     -target=aws_s3_bucket_versioning.terraform_state \
     -target=aws_s3_bucket_server_side_encryption_configuration.terraform_state \
     -target=aws_s3_bucket_public_access_block.terraform_state \
     -target=aws_dynamodb_table.terraform_locks
   ```

3. **Configure Terraform Variables:**
   Edit `terraform/terraform.tfvars`:
   ```hcl
   project_name = "twin"
   environment  = "dev"
   bedrock_model_id = "amazon.nova-lite-v1:0"
   ```

### Deploy

**Using the deployment script:**
```bash
./scripts/deploy.sh dev
```

**Or manually:**
```bash
# Build Lambda package
cd backend
uv run deploy.py

# Deploy infrastructure
cd ../terraform
terraform workspace select dev
terraform init -backend-config="bucket=twin-terraform-state-ACCOUNT_ID" \
  -backend-config="key=dev/terraform.tfstate" \
  -backend-config="region=us-west-2" \
  -backend-config="dynamodb_table=twin-terraform-locks" \
  -backend-config="encrypt=true"
terraform apply

# Deploy frontend
cd ../frontend
npm run build
aws s3 sync ./out s3://twin-dev-frontend-ACCOUNT_ID/ --delete
```

### Destroy

```bash
./scripts/destroy.sh dev
```

## 🔧 Configuration

### Environment Variables

**Backend (Lambda):**
- `BEDROCK_MODEL_ID` - Bedrock model to use (default: `amazon.nova-lite-v1:0`)
- `USE_S3` - Use S3 for memory storage (`true`/`false`)
- `S3_BUCKET` - S3 bucket name for memory storage
- `CORS_ORIGINS` - Comma-separated list of allowed origins
- `DEFAULT_AWS_REGION` - AWS region (default: `us-east-1`)

**Frontend:**
- `NEXT_PUBLIC_API_URL` - API Gateway URL

### Terraform Variables

See `terraform/variables.tf` for all available variables. Key variables:

- `project_name` - Resource name prefix
- `environment` - Environment (dev/test/prod)
- `bedrock_model_id` - Bedrock model ID
- `lambda_timeout` - Lambda timeout in seconds
- `use_custom_domain` - Enable custom domain
- `root_domain` - Custom domain name

## 📁 Project Structure

```
twin-ai/
├── backend/              # FastAPI backend
│   ├── data/            # Personal data files
│   ├── server.py        # Main FastAPI application
│   ├── context.py        # AI prompt generation
│   ├── resources.py      # Data loading
│   ├── lambda_handler.py # Lambda entry point
│   └── deploy.py        # Lambda package builder
├── frontend/             # Next.js frontend
│   ├── app/             # Next.js app directory
│   ├── components/      # React components
│   └── public/          # Static assets
├── terraform/            # Infrastructure as Code
│   ├── main.tf          # Main resources
│   ├── backend.tf       # Backend configuration
│   ├── variables.tf     # Variable definitions
│   └── outputs.tf       # Output values
├── scripts/             # Deployment scripts
│   ├── deploy.sh        # Deployment script
│   └── destroy.sh      # Destruction script
└── .github/workflows/   # GitHub Actions
    ├── deploy.yml       # Deployment workflow
    └── destroy.yml      # Destruction workflow
```

## 🤖 AI Models

The application supports Amazon Bedrock Nova models:

- **Nova Micro** (`amazon.nova-micro-v1:0`) - Fastest, most cost-effective
- **Nova Lite** (`amazon.nova-lite-v1:0`) - Balanced performance (default)
- **Nova Pro** (`amazon.nova-pro-v1:0`) - Highest capability, best quality

Set the model via `BEDROCK_MODEL_ID` environment variable or Terraform `bedrock_model_id` variable.

## 💾 Memory Storage

Conversation memory can be stored in:

- **Local files** (development): Stored in `memory/` directory
- **S3** (production): Set `USE_S3=true` and configure `S3_BUCKET`

Each conversation session maintains its own memory file identified by `session_id`.

## 🔐 Authentication

### Local Development

Uses AWS SSO profile (configured as `jackson` in scripts):
```bash
aws sso login --profile jackson
```

### GitHub Actions

Uses OIDC authentication. Configure:
1. Create IAM role for GitHub Actions (see `terraform/github-oidc.tf`)
2. Set GitHub secrets:
   - `AWS_ROLE_ARN` - IAM role ARN
   - `AWS_ACCOUNT_ID` - AWS account ID
   - `DEFAULT_AWS_REGION` - AWS region

## 🧪 Testing

**Backend:**
```bash
cd backend
pytest  # If tests exist
```

**Frontend:**
```bash
cd frontend
npm run lint
npm run build
```

## 📝 Scripts

### Deployment Script

```bash
./scripts/deploy.sh [environment] [project_name]
```

- Automatically handles SSO login
- Builds Lambda package
- Initializes Terraform with S3 backend
- Deploys infrastructure
- Builds and deploys frontend

### Destroy Script

```bash
./scripts/destroy.sh [environment]
```

- Empties S3 buckets
- Destroys Terraform infrastructure

## 🐛 Troubleshooting

### SSO Token Expired
```bash
aws sso login --profile jackson
```

### Region Mismatch
The scripts automatically detect the S3 bucket region. Ensure `DEFAULT_AWS_REGION` is set correctly.

### Lambda Package Too Large
The deployment script uses Docker to build Lambda-compatible packages. Ensure Docker is running.

### CORS Errors
Verify `CORS_ORIGINS` environment variable includes your frontend domain.

## 📚 Documentation

- [Day 1: Local Development](./week2/day1.md)
- [Day 2: AWS Deployment](./week2/day2.md)
- [Day 3: Bedrock Integration](./week2/day3.md)
- [Day 4: Infrastructure as Code](./week2/day4.md)
- [Day 5: CI/CD with GitHub Actions](./week2/day5.md)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

[Add your license here]

## 🙏 Acknowledgments

Built as part of an AI deployment course, demonstrating production-ready AWS serverless architecture.

---

**Note**: Remember to keep your personal data files (`backend/data/*`) private and never commit sensitive information.
