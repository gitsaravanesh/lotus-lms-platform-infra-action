# Lambda Functions

This directory contains AWS Lambda functions used by the LMS platform.

## get_user_tenant.py

### Purpose
Retrieves user-tenant mapping information from the DynamoDB `lms-user-tenant-mapping` table.

### API Endpoint
```
GET /user/tenant?user_id={user_id}
```

### Request Parameters
- **user_id** (required): The user identifier (Cognito username or email)
  - Can be passed as a query parameter: `?user_id=user@example.com`
  - Or as a header: `User-Id: user@example.com`

### Response Format

**Success (200):**
```json
{
  "user_id": "cloudtech.trainer@gmail.com",
  "tenant_id": "trainer1",
  "role": "instructor",
  "email": "cloudtech.trainer@gmail.com",
  "created_at": "2025-01-10T10:00:00Z"
}
```

**Missing user_id (400):**
```json
{
  "error": "Missing required parameter: user_id",
  "message": "Please provide user_id as a query parameter or header"
}
```

**User not found (404):**
```json
{
  "error": "User mapping not found",
  "message": "No tenant mapping found for user_id: user@example.com"
}
```

**Server error (500):**
```json
{
  "error": "Internal server error",
  "message": "Failed to retrieve user mapping from database"
}
```

### Environment Variables
- `USER_TENANT_MAPPING_TABLE`: Name of the DynamoDB table containing user-tenant mappings

### CORS
The function returns appropriate CORS headers:
- `Access-Control-Allow-Origin: *`
- `Access-Control-Allow-Headers: Content-Type,X-Tenant-Id,Authorization`
- `Access-Control-Allow-Methods: GET,OPTIONS`

### Deployment
The Lambda function is deployed via Terraform and GitHub Actions. The code is packaged and uploaded to the S3 bucket `lms-infra-lambda-artifacts` under the key `lambda/get_user_tenant.zip`.

To deploy changes:
1. Update the Python code in this file
2. The CI/CD pipeline will automatically package and deploy on merge to main
