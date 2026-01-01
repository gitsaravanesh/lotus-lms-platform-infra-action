# CloudFront Deployment Guide

## Pre-Deployment Checklist

- [ ] Review Terraform plan output
- [ ] Backup current CloudFront configuration
- [ ] Verify S3 bucket has `index.html`
- [ ] Check that current app is working
- [ ] Note current CloudFront distribution ID

## Deployment Steps

### 1. Backup Current Configuration

```bash
# Export current CloudFront config
aws cloudfront get-distribution-config \
  --id YOUR_DISTRIBUTION_ID \
  --output json > cloudfront-backup-$(date +%Y%m%d).json
```

### 2. Apply Terraform Changes

```bash
cd terraform/envs/dev
terraform init
terraform plan -out=tfplan
# Review the plan carefully
terraform apply tfplan
```

### 3. Wait for CloudFront Update

CloudFront updates take **10-15 minutes** to complete. Monitor status:

```bash
aws cloudfront get-distribution --id YOUR_DISTRIBUTION_ID \
  --query 'Distribution.Status' --output text

# Wait until output shows: Deployed
```

### 4. Test the Changes

```bash
# Test root URL
curl -I https://your-domain.cloudfront.net/

# Test SPA routes (should return 200, not 404)
curl -I https://your-domain.cloudfront.net/dashboard
curl -I https://your-domain.cloudfront.net/login
curl -I https://your-domain.cloudfront.net/courses/test123

# All should return HTTP 200 with content-type: text/html
```

### 5. Invalidate Cache (Optional)

```bash
aws cloudfront create-invalidation \
  --distribution-id YOUR_DISTRIBUTION_ID \
  --paths "/*"
```

## Rollback Procedure

### Option 1: Terraform Revert (Recommended)

```bash
# Checkout previous commit
git log --oneline  # Find the commit before the change
git revert <commit-hash>

# Apply previous state
cd terraform/envs/dev
terraform apply
```

### Option 2: Manual AWS Console Rollback

1. Go to [CloudFront Console](https://console.aws.amazon.com/cloudfront)
2. Select your distribution
3. Click **Error Pages** tab
4. Delete the two custom error response rules
5. Wait for deployment (~10-15 minutes)

### Option 3: Restore from Backup

```bash
# Get ETag from backup
ETAG=$(jq -r '.ETag' cloudfront-backup-*.json)

# Update distribution with backup config
aws cloudfront update-distribution \
  --id YOUR_DISTRIBUTION_ID \
  --if-match $ETAG \
  --distribution-config file://cloudfront-backup-*.json
```

## Verification

After deployment, verify:

- [ ] Root URL loads: `https://your-domain.cloudfront.net/`
- [ ] Dashboard route works: `https://your-domain.cloudfront.net/dashboard`
- [ ] Page refresh doesn't break
- [ ] OAuth login/signup flows work
- [ ] No console errors in browser

## Troubleshooting

### Issue: Routes still return 404

**Cause:** CloudFront cache hasn't updated yet

**Solution:** Wait 10-15 minutes or create invalidation:
```bash
aws cloudfront create-invalidation \
  --distribution-id YOUR_DISTRIBUTION_ID \
  --paths "/*"
```

### Issue: Terraform apply fails

**Cause:** State mismatch or AWS permissions

**Solution:**
```bash
terraform refresh
terraform plan
# If plan looks correct:
terraform apply
```

### Issue: OAuth redirects break

**Cause:** Query strings not being forwarded

**Solution:** Verify `query_string = true` in cache behavior

## Post-Deployment

- [ ] Monitor CloudWatch metrics for errors
- [ ] Check S3 bucket access logs
- [ ] Update documentation with new distribution URL
- [ ] Notify team of changes

## Support

If issues persist after rollback:
- Check CloudWatch Logs for CloudFront
- Review S3 bucket policy
- Verify `index.html` exists in S3 bucket
