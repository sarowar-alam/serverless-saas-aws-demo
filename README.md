# AWS Serverless SaaS Workshop - Complete Demo

A fully functional, production-ready multi-tenant SaaS application demo built with AWS serverless services. This demo includes complete frontend (3 Angular apps) and backend (Lambda, API Gateway, DynamoDB, Cognito) with automated deployment.

## 🏗️ Architecture

- **Pooled Multi-Tenant**: All tenants share infrastructure with logical data isolation
- **Fully Serverless**: Lambda, API Gateway, DynamoDB, Cognito, S3, CloudFront
- **3 Web Applications**:
  - **Admin UI**: System administrator dashboard for tenant management
  - **Landing UI**: Public tenant registration page
  - **Application UI**: Tenant user interface for products and orders

## 📋 Prerequisites

Before starting, ensure you have:

- **AWS Account** with appropriate permissions
- **AWS CLI v2+** - [Install Guide](https://aws.amazon.com/cli/)
- **AWS SAM CLI v1.50+** - [Install Guide](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html)
- **Python 3.9+** - [Download](https://www.python.org/downloads/)
- **Node.js v16+** - [Download](https://nodejs.org/)
- **Docker Desktop** - [Download](https://www.docker.com/products/docker-desktop)
- **PowerShell** (Windows)

### Verify Prerequisites

```powershell
.\scripts\utils\validate-prereqs.ps1
```

## ⚙️ Configuration

### 1. AWS Profile Setup

Ensure your AWS profile `sarowar-ostad` is configured:

```powershell
aws configure list --profile sarowar-ostad
```

If not configured:

```powershell
aws configure --profile sarowar-ostad
```

### 2. Environment Configuration

The `.env` file is already configured with:

```bash
AWS_PROFILE=sarowar-ostad
AWS_REGION=ap-south-1
DEMO_STACK_PREFIX=demo-saas
DEMO_ADMIN_EMAIL=test@test.com
```

**Important**: Update `DEMO_ADMIN_EMAIL` to your actual email address to receive admin credentials.

## 🚀 Deployment

### Quick Deploy (All-in-One)

```powershell
.\deploy.ps1
```

This runs all deployment steps automatically (~40-50 minutes total).

### Manual Step-by-Step Deployment

```powershell
# Step 1: Validate prerequisites
.\scripts\utils\validate-prereqs.ps1

# Step 2: Deploy shared infrastructure (15-20 min)
.\scripts\01-deploy-shared.ps1

# Step 3: Deploy tenant stack (8-10 min)
.\scripts\02-deploy-tenant.ps1

# Step 4: Build client applications (15-20 min)
.\scripts\03-build-clients.ps1

# Step 5: Deploy clients (requires completion)
# .\scripts\04-deploy-clients.ps1

# Step 6: Create test tenants (requires completion)
# .\scripts\05-create-test-tenants.ps1
```

## 🌐 Accessing the Applications

After deployment, retrieve URLs:

```powershell
.\scripts\geturl.ps1
```

### Admin UI (System Administrator)
- **URL**: `https://[CloudFront-URL-1]`
- **Username**: `admin`
- **Password**: Check email at `DEMO_ADMIN_EMAIL`
- **Features**: Manage all tenants, users, activate tenants

### Landing UI (Public Registration)
- **URL**: `https://[CloudFront-URL-2]`
- **No Login Required**
- **Features**: Self-service tenant registration

### Application UI (Tenant Users)
- **URL**: `https://[CloudFront-URL-3]`
- **Login**: Tenant user credentials from registration
- **Features**: Product and order management

## 📊 What's Deployed

### AWS Resources

**Compute & API:**
- ~25 Lambda functions (Python 3.9)
- 2 API Gateways (Admin + Tenant)
- Lambda Layers (shared utilities)

**Data Storage:**
- 4 DynamoDB tables (TenantDetails, TenantUserMapping, Product, Order)
- 3 S3 buckets (one per UI)

**Identity:**
- 2 Cognito User Pools (Admin + Tenant)
- JWT-based authentication

**CDN:**
- 3 CloudFront distributions (one per UI)

**Monitoring:**
- CloudWatch Logs for all Lambdas
- X-Ray tracing enabled
- CloudWatch metrics

### CloudFormation Stacks

1. **demo-saas-shared**: Control plane (DynamoDB, Cognito, Admin API, UIs)
2. **demo-saas-pooled**: Application plane (Product/Order services, Tenant API)

## 🔧 Configuration Details

### Stack Names
- Shared Stack: `demo-saas-shared`
- Tenant Stack: `demo-saas-pooled`

### DynamoDB Tables
- `demo-saas-TenantDetails`
- `demo-saas-TenantUserMapping`
- `demo-saas-Product-pooled`
- `demo-saas-Order-pooled`

### IAM Roles
- `demo-saas-pooled-product-function-execution-role`
- `demo-saas-pooled-order-function-execution-role`
- `demo-saas-tenant-authorizer-execution-role`

## 💰 Cost Estimate

**Idle (No Usage):**
- CloudFront: ~$1-2/month (3 distributions)
- DynamoDB: Free tier eligible
- Lambda: Free tier eligible
- S3: ~$0.50-1/month
- **Total: $2-5/month**

**Under Load:**
- Depends on tenant count and usage patterns
- Pooled architecture provides cost efficiency

## 🧪 Testing the Demo

### 1. Login to Admin UI
- Use admin credentials from email
- View system dashboard

### 2. Register a Tenant (Landing UI)
- Fill tenant registration form
- Note the tenant ID from response

### 3. Activate Tenant (Admin UI)
- Login as admin
- Navigate to tenants
- Activate the new tenant

### 4. Login as Tenant User (Application UI)
- Use credentials from registration
- Create products and orders
- Test multi-tenant data isolation

## 📖 Architecture Highlights

### Pooled Multi-Tenancy
- Shared Lambda functions across all tenants
- Data isolation via shard-based partitioning
- Tenant context propagated through JWT authorizers

### Security
- Cognito for authentication
- Custom Lambda authorizers for authorization
- Tenant-scoped data access
- Separate user pools for admins vs tenants

### Observability
- CloudWatch Logs per Lambda function
- X-Ray distributed tracing
- Custom metrics with tenant dimensions
- Lambda Insights enabled

## 🛠️ Troubleshooting

### SAM Build Fails
```powershell
# Ensure Docker is running
docker ps

# Retry with verbose output
sam build --use-container --debug
```

### Stack Deployment Fails
```powershell
# Check CloudFormation events
aws cloudformation describe-stack-events `
  --stack-name demo-saas-shared `
  --profile sarowar-ostad `
  --region ap-south-1
```

### Client Build Fails
```powershell
# Clear node_modules and retry
cd client/Admin
Remove-Item -Recurse -Force node_modules
npm cache clean --force
npm install
```

### Can't Access URLs
- CloudFront distributions take 10-15 minutes to fully propagate
- Check if stacks are in `CREATE_COMPLETE` state
- Verify S3 buckets have content

## 🧹 Cleanup

To remove all AWS resources:

```powershell
.\cleanup.ps1
```

This will:
1. Empty all S3 buckets
2. Delete tenant stack (demo-saas-pooled)
3. Delete shared stack (demo-saas-shared)
4. Delete SAM artifacts bucket
5. Optionally purge CloudWatch logs

**Cleanup time: 20-35 minutes** (CloudFront deletion is slow)

For manual cleanup instructions, see [CLEANUP.md](CLEANUP.md)

## 📚 Additional Resources

- [AWS SaaS Factory](https://aws.amazon.com/partners/programs/saas-factory/)
- [Original Workshop](https://catalog.us-east-1.prod.workshops.aws/v2/workshops/b0c6ad36-0a4b-45d8-856b-8a64f0ac76bb/)
- [Serverless SaaS Reference](https://github.com/aws-samples/aws-saas-factory-ref-solution-serverless-saas)

## 📝 License

This demo is based on AWS samples and follows MIT-0 license.

## 🤝 Support

For issues or questions:
1. Check CloudFormation stack events
2. Review CloudWatch logs
3. Verify all prerequisites are installed
4. Ensure AWS profile has necessary permissions

---

**Created**: January 2026  
**AWS Profile**: sarowar-ostad  
**Region**: ap-south-1 (Mumbai)
