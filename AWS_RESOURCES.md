# AWS Resources Created by DEMO Deployment

This document lists all AWS resources created when deploying the multi-tenant SaaS application.

## Deployment Information
- **Stack Prefix**: `demo-saas` (configurable)
- **AWS Region**: Configurable via `.env` file
- **Deployment Date**: January 2026

---

## CloudFormation Stacks

### 1. Shared Stack (Control Plane)
**Stack Name**: `demo-saas-shared`

This stack contains all shared resources used by the control plane (admin operations).

**Nested Stacks**:
- `demo-saas-shared-DynamoDBTables-*` - Database tables
- `demo-saas-shared-UserInterface-*` - S3 buckets and CloudFront distributions
- `demo-saas-shared-Cognito-*` - User pools and identity management
- `demo-saas-shared-LambdaFunctions-*` - Lambda functions and layers
- `demo-saas-shared-APIs-*` - API Gateway endpoints

### 2. Tenant Stack (Application Plane)
**Stack Name**: `demo-saas-pooled`

This stack contains all tenant-facing resources for the application plane.

**Nested Stacks**:
- `demo-saas-pooled-DynamoDBTables-*` - Tenant data tables
- `demo-saas-pooled-LambdaFunctions-*` - Business logic functions
- `demo-saas-pooled-APIs-*` - Tenant API Gateway

---

## DynamoDB Tables (4 Tables)

### Control Plane Tables

#### 1. TenantDetails Table
- **Name**: `demo-saas-TenantDetails`
- **Purpose**: Stores tenant metadata and configuration
- **Primary Key**: `tenantId` (String)
- **Attributes**: tenantName, tenantEmail, tenantTier, isActive, etc.

#### 2. TenantUserMapping Table
- **Name**: `demo-saas-TenantUserMapping`
- **Purpose**: Maps users to tenants for access control
- **Primary Key**: `tenantId` (String), `userName` (String)
- **Use Case**: Multi-tenant user isolation

### Application Plane Tables (Pooled Architecture)

#### 3. Product Table
- **Name**: `demo-saas-Product-pooled`
- **Purpose**: Stores product data for all tenants (with tenant isolation via shardId)
- **Primary Key**: `shardId` (String - contains tenantId), `productId` (String)
- **GSI**: Query products by category and tenant

#### 4. Order Table
- **Name**: `demo-saas-Order-pooled`
- **Purpose**: Stores order data for all tenants (with tenant isolation via shardId)
- **Primary Key**: `shardId` (String - contains tenantId), `orderId` (String)
- **GSI**: Query orders by tenant and date

---

## Amazon Cognito (2 User Pools)

### 1. Admin User Pool (Operation Users)
- **Pool ID**: `ap-south-1_VU89mDTLJ`
- **App Client ID**: `6jk45rug890kk89jfobehrj69f`
- **Purpose**: Authentication for system administrators and SaaS operators
- **Users**: System admins who manage tenants
- **Custom Attributes**: `custom:userRole`, `custom:tenantId`

### 2. Tenant User Pool
- **Pool ID**: `ap-south-1_jFVOFdJoQ`
- **App Client ID**: `407he6r8lt9uijknaifaih6chb`
- **Purpose**: Authentication for tenant users (customers)
- **Users**: Tenant admins and end users
- **Custom Attributes**: `custom:userRole`, `custom:tenantId`

---

## API Gateway (2 REST APIs)

### 1. Admin API (Control Plane)
- **API ID**: `3f0tmsxor5`
- **Endpoint**: `https://3f0tmsxor5.execute-api.ap-south-1.amazonaws.com/prod`
- **Stage**: `prod`
- **Purpose**: Tenant management operations (CRUD tenants, users)

**Endpoints**:
- `POST /tenant` - Create new tenant
- `GET /tenants` - List all tenants
- `GET /tenant/{tenant-id}` - Get tenant details
- `PUT /tenant/{tenant-id}` - Update tenant
- `POST /tenant/activate` - Activate tenant
- `POST /tenant/disable` - Deactivate tenant
- `POST /registration` - Tenant self-registration
- `POST /user/tenant-admin` - Create tenant admin user
- `GET /users` - List users
- `GET /user/{user-name}` - Get user details
- `PUT /user/{user-name}` - Update user
- `POST /user/disable` - Disable user

**Authorizer**: SharedServicesAuthorizerFunction (validates JWT from both user pools)

### 2. Tenant API (Application Plane)
- **API ID**: `9ajkik3ree`
- **Endpoint**: `https://9ajkik3ree.execute-api.ap-south-1.amazonaws.com/prod`
- **Stage**: `prod`
- **Purpose**: Business operations (products, orders)

**Endpoints**:
- `GET /products` - List products for tenant
- `GET /product/{product-id}` - Get product details
- `POST /product` - Create new product
- `PUT /product/{product-id}` - Update product
- `DELETE /product/{product-id}` - Delete product
- `GET /orders` - List orders for tenant
- `GET /order/{order-id}` - Get order details
- `POST /order` - Create new order
- `PUT /order/{order-id}` - Update order
- `DELETE /order/{order-id}` - Delete order

**Authorizer**: BusinessServicesAuthorizerFunction (validates tenant JWT, injects tenantId)

---

## AWS Lambda Functions (27 Functions)

### Shared Stack Functions (15 Functions)

#### Authentication & Authorization (2)
1. **SharedServicesAuthorizerFunction**
   - Handler: `shared_service_authorizer.lambda_handler`
   - Purpose: Validates JWT tokens for Admin API
   - Enhancements: Added `policy.allowAllMethods()`

2. **BusinessServicesAuthorizerFunction** (Tenant Authorizer)
   - Handler: `tenant_authorizer.lambda_handler`
   - Purpose: Validates JWT tokens for Tenant API
   - Enhancements: Added `tenantId` to authorizer context, includes python-jose dependencies

#### Tenant Management (6)
3. **RegisterTenantFunction**
   - Handler: `tenant-registration.register_tenant`
   - Purpose: Handle tenant self-registration workflow
   - Environment: CREATE_TENANT_ADMIN_USER_RESOURCE_PATH, CREATE_TENANT_RESOURCE_PATH

4. **CreateTenantFunction**
   - Handler: `tenant-management.create_tenant`
   - Purpose: Create tenant record in DynamoDB

5. **GetTenantsFunction**
   - Handler: `tenant-management.get_tenants`
   - Purpose: List all tenants

6. **GetTenantFunction**
   - Handler: `tenant-management.get_tenant`
   - Purpose: Get single tenant details

7. **UpdateTenantFunction**
   - Handler: `tenant-management.update_tenant`
   - Purpose: Update tenant information

8. **DeactivateTenantFunction**
   - Handler: `tenant-management.deactivate_tenant`
   - Purpose: Disable tenant access

9. **ActivateTenantFunction**
   - Handler: `tenant-management.activate_tenant`
   - Purpose: Enable tenant access

#### User Management (6)
10. **CreateTenantAdminUserFunction**
    - Handler: `user-management.create_tenant_admin_user`
    - Purpose: Create admin user for new tenant
    - Environment: TENANT_USER_POOL_ID, TENANT_APP_CLIENT_ID

11. **CreateUserFunction**
    - Handler: `user-management.create_user`
    - Purpose: Create regular tenant user

12. **GetUsersFunction**
    - Handler: `user-management.get_users`
    - Purpose: List users for tenant

13. **GetUserFunction**
    - Handler: `user-management.get_user`
    - Purpose: Get single user details

14. **UpdateUserFunction**
    - Handler: `user-management.update_user`
    - Purpose: Update user information

15. **DisableUserFunction**
    - Handler: `user-management.disable_user`
    - Purpose: Disable user access

### Tenant Stack Functions (12 Functions)

#### Product Service (6)
16. **GetProductsFunction**
    - Handler: `product-service.get_products`
    - Purpose: List products for tenant

17. **GetProductFunction**
    - Handler: `product-service.get_product`
    - Purpose: Get single product details

18. **CreateProductFunction**
    - Handler: `product-service.create_product`
    - Purpose: Create new product
    - Enhancements: Fully implemented (was TODO in Lab3)

19. **UpdateProductFunction**
    - Handler: `product-service.update_product`
    - Purpose: Update product information

20. **DeleteProductFunction**
    - Handler: `product-service.delete_product`
    - Purpose: Delete product

#### Order Service (6)
21. **GetOrdersFunction**
    - Handler: `order-service.get_orders`
    - Purpose: List orders for tenant

22. **GetOrderFunction**
    - Handler: `order-service.get_order`
    - Purpose: Get single order details

23. **CreateOrderFunction**
    - Handler: `order-service.create_order`
    - Purpose: Create new order

24. **UpdateOrderFunction**
    - Handler: `order-service.update_order`
    - Purpose: Update order information

25. **DeleteOrderFunction**
    - Handler: `order-service.delete_order`
    - Purpose: Delete order

### Lambda Layers (1)
26. **ServerlessSaaSLayers**
    - Name: `serverless-saas-dependencies`
    - Purpose: Shared utilities and dependencies
    - Runtime: Python 3.9
    - Contents: logger, utils, metrics_manager, auth_manager

**Global Environment Variables** (All Lambda Functions):
- `STACK_PREFIX`: `demo-saas`
- `LOG_LEVEL`: `DEBUG`
- `POWERTOOLS_METRICS_NAMESPACE`: `ServerlessSaaS`
- `AWS_REGION`: `ap-south-1`

---

## Amazon S3 Buckets (4 Buckets)

### 1. SAM Artifacts Bucket
- **Name**: `demo-saas-sam-artifacts-f94db367`
- **Purpose**: Stores SAM deployment packages and templates
- **Contents**: Lambda function code, nested templates, build artifacts

### 2. Admin UI Bucket
- **Name**: `demo-saas-shared-userinterface-*-adminbucket-*`
- **Purpose**: Hosts Admin UI static files
- **Contents**: Angular Admin application (dist/)
- **CloudFront**: Serves content via CDN

### 3. Landing UI Bucket
- **Name**: `demo-saas-shared-userinterface-*-landingappbucket-*`
- **Purpose**: Hosts Landing/Registration UI static files
- **Contents**: Angular Landing application (dist/)
- **CloudFront**: Serves content via CDN

### 4. Application UI Bucket
- **Name**: `demo-saas-shared-userinterface-*-appbucket-*`
- **Purpose**: Hosts Application UI static files
- **Contents**: Angular Application UI (dist/)
- **CloudFront**: Serves content via CDN

---

## Amazon CloudFront Distributions (3 Distributions)

### 1. Admin UI Distribution
- **Distribution ID**: `E3GMEZLL3DQJ9T`
- **Domain**: `d2kr9nht29ell2.cloudfront.net`
- **URL**: `https://d2kr9nht29ell2.cloudfront.net`
- **Purpose**: Serves Admin Management UI
- **Origin**: Admin S3 bucket
- **Features**: Tenant management, user management

### 2. Landing UI Distribution
- **Distribution ID**: `E1TP5XKQV35O7N`
- **Domain**: `d1anzfh5z8er19.cloudfront.net`
- **URL**: `https://d1anzfh5z8er19.cloudfront.net`
- **Purpose**: Serves Landing/Registration page
- **Origin**: Landing S3 bucket
- **Features**: Tenant self-registration

### 3. Application UI Distribution
- **Distribution ID**: `E1TCJTZS162C1K`
- **Domain**: `d205pzi1iv7uca.cloudfront.net`
- **URL**: `https://d205pzi1iv7uca.cloudfront.net`
- **Purpose**: Serves Tenant Application UI
- **Origin**: Application S3 bucket
- **Features**: Product management, order management

---

## IAM Roles (8 Roles)

### Lambda Execution Roles

1. **authorizer-execution-role**
   - Used by: SharedServicesAuthorizerFunction, BusinessServicesAuthorizerFunction
   - Permissions: DynamoDB GetItem (TenantDetails), Cognito List*, CloudWatch Logs

2. **tenant-userpool-lambda-execution-role-ap-south-1**
   - Used by: Tenant user pool related functions
   - Permissions: Cognito full access, DynamoDB GetItem/Query

3. **create-user-lambda-execution-role-ap-south-1**
   - Used by: CreateTenantAdminUserFunction, CreateUserFunction
   - Permissions: Cognito user creation, DynamoDB GetItem

4. **tenant-management-lambda-execution-role-ap-south-1**
   - Used by: All tenant management functions
   - Permissions: DynamoDB PutItem/GetItem/UpdateItem/Scan on TenantDetails

5. **user-management-lambda-execution-role-ap-south-1**
   - Used by: All user management functions
   - Permissions: Cognito operations, DynamoDB TenantUserMapping access

6. **register-tenant-lambda-execution-role-ap-south-1**
   - Used by: RegisterTenantFunction
   - Permissions: API Gateway invoke, Cognito operations, DynamoDB access

7. **product-service-lambda-execution-role-ap-south-1**
   - Used by: All Product service functions
   - Permissions: DynamoDB full access on Product table, CloudWatch metrics

8. **order-service-lambda-execution-role-ap-south-1**
   - Used by: All Order service functions
   - Permissions: DynamoDB full access on Order table, CloudWatch metrics

---

## CloudWatch Resources

### Log Groups (27 Log Groups)
Each Lambda function has a dedicated log group:
- `/aws/lambda/demo-saas-shared-LambdaFunctions-*-SharedServicesAuthorizerFunction-*`
- `/aws/lambda/demo-saas-shared-LambdaFunctions-*-RegisterTenantFunction-*`
- `/aws/lambda/demo-saas-shared-LambdaFunctions-*-CreateTenantFunction-*`
- ... (24 more for all Lambda functions)

### Metrics (Custom Namespace)
- **Namespace**: `ServerlessSaaS`
- **Metrics**: DynamoDB read/write capacity units, API latency, tenant operations

---

## Resource Summary

| Resource Type | Count | Purpose |
|--------------|-------|---------|
| CloudFormation Stacks | 2 main + 8 nested | Infrastructure as Code |
| DynamoDB Tables | 4 | Data persistence |
| Cognito User Pools | 2 | Authentication |
| API Gateway REST APIs | 2 | RESTful endpoints |
| Lambda Functions | 27 | Business logic |
| Lambda Layers | 1 | Shared dependencies |
| S3 Buckets | 4 | Static hosting + artifacts |
| CloudFront Distributions | 3 | CDN for UIs |
| IAM Roles | 8 | Access control |
| CloudWatch Log Groups | 27 | Logging |

---

## Architecture Patterns

### Multi-Tenancy Model
- **Type**: Pooled (silo-pooled hybrid)
- **Isolation**: Logical (via tenantId in shardId)
- **Control Plane**: Shared resources for tenant management
- **Application Plane**: Shared DynamoDB tables with partition key isolation

### Security
- **Authentication**: Amazon Cognito with JWT tokens
- **Authorization**: Custom Lambda authorizers
- **API Security**: API Gateway with authorizers
- **Data Isolation**: Tenant ID in partition keys

### Scalability
- **Serverless**: Auto-scales with demand
- **DynamoDB**: On-demand capacity
- **API Gateway**: Handles millions of requests
- **CloudFront**: Global CDN for low latency

---

## Cleanup

To delete all resources, run:
```powershell
cd DEMO/scripts
.\cleanup.ps1
```

This will remove:
1. Tenant stack (demo-saas-pooled)
2. All S3 bucket contents
3. Shared stack (demo-saas-shared)
4. SAM artifacts bucket
5. All CloudWatch log groups

**Note**: Cognito user pools, DynamoDB tables, and all nested resources are automatically deleted when the parent stacks are removed.

---

## Cost Optimization

### Free Tier Eligible
- Lambda: 1M requests/month free
- API Gateway: 1M requests/month free (12 months)
- DynamoDB: 25GB storage + 25 RCU/WCU free
- CloudFront: 50GB data transfer/month free (12 months)
- Cognito: 50,000 MAUs free

### Estimated Monthly Cost (Beyond Free Tier)
- Lambda: ~$1-5 (based on usage)
- DynamoDB: ~$2-10 (depends on data size)
- API Gateway: ~$1-5 (per million requests)
- CloudFront: ~$1-10 (data transfer)
- S3: <$1 (static files)
- **Total**: ~$5-30/month for moderate usage

---

## 🧑‍💻 Author

**Md. Sarowar Alam**  
Lead DevOps Engineer, Hogarth Worldwide  
📧 Email: sarowar@hotmail.com  
🔗 LinkedIn: [linkedin.com/in/sarowar](https://www.linkedin.com/in/sarowar/)

---
