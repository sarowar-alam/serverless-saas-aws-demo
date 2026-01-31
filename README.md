# AWS Serverless SaaS Workshop - Complete Demo

A fully functional, production-ready multi-tenant SaaS application demo built with AWS serverless services. This demo includes complete frontend (3 Angular apps) and backend (Lambda, API Gateway, DynamoDB, Cognito) with automated deployment.

## 🎯 What Makes This Demo Different

This is an **enhanced version** of the AWS Serverless SaaS Workshop with:

✅ **10+ Bug Fixes** - All runtime issues from the original workshop resolved  
✅ **Automated Deployment** - PowerShell scripts with intelligent error handling  
✅ **Complete Documentation** - Step-by-step guides and troubleshooting  
✅ **Production-Ready** - Tested deployment and cleanup workflows  
✅ **Self-Configuring** - Automatic SAM bucket and environment management  

**Perfect for**: Learning multi-tenant SaaS architecture, AWS serverless development, or building your own SaaS MVP.

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

Create a `.env` file by copying `.env.example`:

```powershell
Copy-Item .env.example .env
```

Update the `.env` file with your settings:

```bash
AWS_PROFILE=your-aws-profile-name
AWS_REGION=ap-south-1  # Or your preferred region
DEMO_STACK_PREFIX=demo-saas
DEMO_ADMIN_EMAIL=your-email@example.com  # You'll receive admin credentials here
SAM_S3_BUCKET=  # Leave empty - automatically managed by deployment scripts
```

**Important Notes**:
- Change `AWS_PROFILE` to your AWS CLI profile name
- Update `DEMO_ADMIN_EMAIL` to receive admin password via email
- `SAM_S3_BUCKET` is auto-populated during deployment (no manual configuration needed)

## 🚀 Deployment

### Quick Deploy (All-in-One)

```powershell
.\deploy.ps1
```

This runs all deployment steps automatically (~40-50 minutes total).

### Manual Step-by-Step Deployment

```powershell
# Step 1: Deploy shared infrastructure (control plane: DynamoDB, Cognito, Admin API, UIs)
# Time: 15-20 minutes
.\scripts\01-deploy-shared.ps1

# Step 2: Deploy tenant stack (application plane: Product/Order services, Tenant API)
# Time: 8-10 minutes
.\scripts\02-deploy-tenant.ps1

# Step 3: Build client applications (Angular compilation)
# Time: 15-20 minutes
.\scripts\03-build-clients.ps1

# Step 4: Deploy clients to S3 (upload built apps)
# Time: 1-2 minutes
.\scripts\04-deploy-clients.ps1
```

**Note**: If you run cleanup and redeploy, you must delete the shared stack before redeploying:

```powershell
# After cleanup, force stack deletion
aws cloudformation delete-stack --stack-name demo-saas-shared --profile your-profile --region your-region
aws cloudformation wait stack-delete-complete --stack-name demo-saas-shared --profile your-profile --region your-region

# Then redeploy from Step 1
```

This is necessary because CloudFormation UPDATE mode doesn't recreate S3 buckets after they've been deleted.

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

## ✨ Bug Fixes Included

This demo includes fixes for 10+ runtime issues from the original AWS workshop:

1. **Dynamic Table Names**: Fixed hardcoded DynamoDB table names with `STACK_PREFIX` environment variable
2. **Authorization Policy**: Added `policy.allowAllMethods()` in shared services authorizer
3. **Tenant Context**: Added missing `tenantId` to authorizer context for tenant isolation
4. **Product Creation**: Implemented missing `create_product()` function in DAL layer
5. **Cognito Configuration**: Fixed missing Cognito pool IDs in Application UI environment
6. **Users Menu**: Disabled non-existent `/users` endpoint in Application UI navigation
7. **Lambda Environment Variables**: Added `STACK_PREFIX` to all Lambda function environments
8. **Tenant Registration**: Fixed missing environment variables in registration workflow
9. **PowerShell Cleanup**: Fixed JMESPath query syntax errors in cleanup script
10. **SAM Bucket Management**: Automated SAM bucket creation and `.env` synchronization

All fixes are permanently saved in source code - no manual updates needed after deployment!

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
  --profile your-profile `
  --region your-region
```

### Client Build Fails
```powershell
# Clear node_modules and retry
cd client/Admin
Remove-Item -Recurse -Force node_modules
npm cache clean --force
npm install
```

### S3 Buckets Don't Exist After Redeploy
**Symptom**: `NoSuchBucket` error when running `04-deploy-clients.ps1`

**Cause**: CloudFormation UPDATE doesn't recreate deleted S3 buckets

**Solution**: Force stack deletion before redeploying:
```powershell
.\cleanup.ps1  # Or manual deletion
aws cloudformation delete-stack --stack-name demo-saas-shared --profile your-profile --region your-region
aws cloudformation wait stack-delete-complete --stack-name demo-saas-shared --profile your-profile --region your-region
.\scripts\01-deploy-shared.ps1  # Fresh deployment
```

### Can't Access URLs
- CloudFront distributions take 10-15 minutes to fully propagate
- Check if stacks are in `CREATE_COMPLETE` state
- Verify S3 buckets have content:
  ```powershell
  aws s3 ls s3://your-bucket-name --profile your-profile
  ```

### SAM Bucket Issues
- Deployment scripts automatically create/update SAM S3 bucket
- `.env` file is auto-updated with correct bucket name
- If bucket name mismatch occurs, clear `SAM_S3_BUCKET=` in `.env` and redeploy

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
- [Serverless SaaS Reference](https://github.com/aws-samples/aws-saas-factory-ref-solution-serverless-saas)

## 🤝 Support

For issues or questions:
1. Check CloudFormation stack events
2. Review CloudWatch logs
3. Verify all prerequisites are installed
4. Ensure AWS profile has necessary permissions

---

## 🧑‍💻 Author

**Md. Sarowar Alam**  
Lead DevOps Engineer, Hogarth Worldwide  
📧 Email: sarowar@hotmail.com  
🔗 LinkedIn: [linkedin.com/in/sarowar](https://www.linkedin.com/in/sarowar/)

---
