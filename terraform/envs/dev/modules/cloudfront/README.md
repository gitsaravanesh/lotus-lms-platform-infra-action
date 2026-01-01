# CloudFront Module

## Overview
This module provisions a CloudFront distribution for the LMS frontend (React/Flutter Web) with proper SPA routing support.

## Features
- ✅ HTTPS redirect (HTTP → HTTPS)
- ✅ Custom error responses for client-side routing
- ✅ Query string forwarding for OAuth callbacks
- ✅ OPTIONS method support for CORS
- ✅ Optimized cache settings

## SPA Routing Support

The custom error response configuration ensures that:
- Direct URL access works (e.g., `https://domain.com/dashboard`)
- Page refreshes don't break the app
- Bookmarked routes function correctly
- OAuth redirects work properly

### How It Works
When CloudFront receives a request for `/dashboard`:
1. S3 doesn't have a file at that path → returns 404
2. CloudFront intercepts the 404 error
3. Returns `index.html` with 200 status code
4. React/Flutter router handles the `/dashboard` route client-side

## Deployment

After updating this configuration:

```bash
cd terraform/envs/dev
terraform init
terraform plan
terraform apply
```

**Note:** CloudFront updates take 10-15 minutes to propagate globally.

## Testing

After deployment, verify routing works:

```bash
# Test direct URL access (should return 200, not 404)
curl -I https://your-cloudfront-domain.cloudfront.net/dashboard

# Should see:
# HTTP/2 200
# content-type: text/html
```

## Rollback

If issues occur after applying:

```bash
# Revert to previous Terraform state
terraform state pull > backup.tfstate
git revert HEAD
terraform apply
```

Or use the AWS Console:
1. Go to CloudFront → Distributions
2. Select your distribution
3. Edit → Error Pages
4. Remove custom error responses if needed
