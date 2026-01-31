# 🚀 Quick Start Guide

## What You Have

A complete, production-ready AWS Serverless SaaS demo in the `DEMO/` folder:

```
DEMO/
├── .env                          # Your configuration (AWS profile: sarowar-ostad, region: ap-south-1)
├── .env.example                  # Template for others
├── deploy.ps1                    # Master deployment script (40-50 min)
├── cleanup.ps1                   # Complete cleanup script (20-35 min)
├── README.md                     # Comprehensive documentation
├── server/                       # Backend (parameterized for reuse)
│   ├── shared-template.yaml      # Control plane CloudFormation
│   ├── tenant-template.yaml      # Application plane CloudFormation
│   ├── shared-samconfig.toml     # SAM config (auto-populated)
│   ├── tenant-samconfig.toml     # SAM config (auto-populated)
│   ├── nested_templates/         # Modular CloudFormation templates
│   ├── layers/                   # Python Lambda layers
│   ├── TenantManagementService/  # Tenant CRUD & onboarding
│   ├── ProductService/           # Product management
│   ├── OrderService/             # Order management
│   └── Resources/                # Authorizers
├── client/                       # Frontend (3 Angular apps)
│   ├── Admin/                    # System admin UI
│   ├── Landing/                  # Public registration UI
│   └── Application/              # Tenant user UI
└── scripts/
    ├── utils/
    │   ├── load-config.ps1       # Load .env variables
    │   └── validate-prereqs.ps1  # Check all tools installed
    ├── 01-deploy-shared.ps1      # Deploy control plane (15-20 min)
    ├── 02-deploy-tenant.ps1      # Deploy application plane (8-10 min)
    ├── 03-build-clients.ps1      # Build all 3 UIs (15-20 min)
    └── geturl.ps1                # Get all CloudFront URLs
```

## Prerequisites Checklist

Before deploying, ensure you have:

- [ ] AWS CLI v2+ installed
- [ ] AWS SAM CLI v1.50+ installed
- [ ] Python 3.9+ installed
- [ ] Node.js v16+ installed
- [ ] Docker Desktop installed and running
- [ ] AWS profile `sarowar-ostad` configured

**Verify all at once:**
```powershell
cd DEMO
.\scripts\utils\validate-prereqs.ps1
```

## Deployment Steps

### Option 1: Quick Deploy (Recommended)

```powershell
cd DEMO

# Update .env with your email to receive admin password
# Then run:
.\deploy.ps1
```

This runs all steps automatically. Estimated time: **40-50 minutes**

### Option 2: Step-by-Step

```powershell
cd DEMO

# Step 1: Validate prerequisites
.\scripts\utils\validate-prereqs.ps1

# Step 2: Deploy shared infrastructure (DynamoDB, Cognito, S3, CloudFront, Admin API)
.\scripts\01-deploy-shared.ps1        # 15-20 minutes

# Step 3: Deploy tenant stack (Product/Order services, Tenant API)
.\scripts\02-deploy-tenant.ps1        # 8-10 minutes

# Step 4: Build all Angular applications
.\scripts\03-build-clients.ps1        # 15-20 minutes

# Step 5: Get application URLs
.\scripts\geturl.ps1
```

## What Gets Deployed

### AWS Resources

**2 CloudFormation Stacks:**
- `demo-saas-shared`: Control plane (15-20 min to create)
- `demo-saas-pooled`: Application plane (8-10 min to create)

**4 DynamoDB Tables:**
- `demo-saas-TenantDetails`
- `demo-saas-TenantUserMapping`
- `demo-saas-Product-pooled`
- `demo-saas-Order-pooled`

**~25 Lambda Functions** (Python 3.9)

**2 API Gateways:**
- Admin API (tenant management)
- Tenant API (products & orders)

**2 Cognito User Pools:**
- Admin/System users
- Tenant users

**3 CloudFront Distributions + S3 Buckets:**
- Admin UI
- Landing UI
- Application UI

**Cost:** ~$2-5/month when idle

## Accessing Your Demo

After deployment:

```powershell
.\scripts\geturl.ps1
```

### 1. Admin UI (System Administrator)
- **URL**: Displayed by geturl.ps1
- **Username**: `admin`
- **Password**: Check email at your `DEMO_ADMIN_EMAIL`
- **Use for**: Managing tenants, activating new registrations

### 2. Landing UI (Public Registration)
- **URL**: Displayed by geturl.ps1
- **No login required**
- **Use for**: Registering new tenants

### 3. Application UI (Tenant Users)
- **URL**: Displayed by geturl.ps1
- **Login**: Tenant credentials from registration
- **Use for**: Creating products and orders

## Demo Workflow

1. **Login to Admin UI**
   - Use admin credentials from email
   - Explore the system dashboard

2. **Register a Tenant** (Landing UI)
   - Fill registration form
   - Note the tenant ID

3. **Activate Tenant** (Admin UI)
   - Login as admin
   - Navigate to Tenants
   - Find and activate your tenant

4. **Login as Tenant User** (Application UI)
   - Use credentials from registration
   - Create products
   - Create orders
   - Test multi-tenant isolation

## Cleanup

When done, remove all AWS resources:

```powershell
.\cleanup.ps1
```

- Type `DELETE` to confirm
- Wait 20-35 minutes (CloudFront is slow)
- All resources will be deleted
- No ongoing charges

## Troubleshooting

### Docker not running
```powershell
# Start Docker Desktop, then retry
docker ps
```

### SAM build fails
```powershell
# Check Docker is running
# Retry with clean build
cd server
sam build --use-container --cached --parallel
```

### Stack deployment fails
```powershell
# Check CloudFormation console
aws cloudformation describe-stack-events `
  --stack-name demo-saas-shared `
  --profile sarowar-ostad `
  --region ap-south-1 `
  --max-items 10
```

### URLs not accessible
- CloudFront takes 10-15 minutes to fully propagate
- Check stack status is `CREATE_COMPLETE`
- Verify S3 buckets have content

## Key Configuration

All configuration is in `.env`:

```bash
AWS_PROFILE=sarowar-ostad        # Your AWS profile
AWS_REGION=ap-south-1            # Mumbai region
DEMO_STACK_PREFIX=demo-saas      # Stack name prefix
DEMO_ADMIN_EMAIL=test@test.com   # Update this!
```

## Architecture Highlights

- **Fully Serverless**: No servers to manage
- **Pooled Multi-Tenancy**: Shared infrastructure, logical isolation
- **Production-Ready**: Security, monitoring, scalability built-in
- **3 Complete UIs**: Admin, public registration, tenant app
- **Automated Deployment**: One command to deploy everything

## Next Steps

1. **Explore the code**: Check parameterized templates in `server/`
2. **Customize**: Modify `.env` for different environments
3. **Add features**: Extend services in `server/` folder
4. **Monitor**: Check CloudWatch logs and metrics
5. **Scale**: Add more tenants and test performance

## Support

For questions or issues:
1. Check [README.md](README.md) for detailed docs
2. Review CloudFormation events
3. Check CloudWatch logs for Lambda errors
4. Verify AWS profile has necessary permissions

---

## 🧑‍💻 Author

**Md. Sarowar Alam**  
Lead DevOps Engineer, Hogarth Worldwide  
📧 Email: sarowar@hotmail.com  
🔗 LinkedIn: [linkedin.com/in/sarowar](https://www.linkedin.com/in/sarowar/)

---
