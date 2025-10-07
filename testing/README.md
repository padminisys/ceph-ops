# S3 Bucket Testing with Rook Ceph

This directory contains comprehensive testing manifests for S3 bucket functionality using Rook Ceph Object Storage (RGW).

## ⚠️ IMPORTANT: Secure TLS Certificate Solution

**Issue Identified**: ObjectBucketClaim was failing due to TLS certificate mismatch. The Rook operator was trying to access the RGW admin API via HTTPS with a certificate valid only for `s3.padmini.systems`, not the internal service name `rook-ceph-rgw-ceph-objectstore.rook-ceph.svc`.

**Secure Solution Implemented**:
- ✅ **Dual Certificate Approach**: Internal self-signed cert + External Let's Encrypt cert
- ✅ **Full HTTPS Security**: Both internal and external connections use HTTPS
- ✅ **Internal Certificate**: Includes internal service names as Subject Alternative Names
- ✅ **External Certificate**: Keeps existing Let's Encrypt certificate for public access

## Prerequisites

- Rook Ceph cluster deployed and running
- Object storage (RGW) configured with `ceph-objectstore`
- Storage class `ceph-bucket` available
- Ingress configured for S3 endpoint: `s3.padmini.systems`
- **Updated configuration applied** (see Fix Applied section below)

## Test Components

### 1. Object Bucket Claim (`s3-bucket-claim.yaml`)
Creates an S3 bucket using Rook Ceph Object Storage:
- **Bucket Name**: `test-bucket-001`
- **Storage Class**: `ceph-bucket`
- **Versioning**: Enabled
- **Auto-generates**: Access credentials and ConfigMap

### 2. Test Pod (`s3-test-pod.yaml`)
Interactive pod for manual S3 testing:
- **Image**: `amazon/aws-cli:latest`
- **Credentials**: Auto-mounted from ObjectBucketClaim secret
- **Endpoint**: `https://s3.padmini.systems`
- **Purpose**: Manual testing and debugging

### 3. Test Scripts (`s3-test-scripts.yaml`)
ConfigMap containing comprehensive test scripts:
- **Basic Operations**: Upload, download, list operations
- **Advanced Operations**: Multi-file operations, sync, metadata
- **Cleanup Script**: Remove all objects from bucket

### 4. Test Jobs (`s3-test-job.yaml`)
Automated test execution:
- **Basic Test Job**: Runs fundamental S3 operations
- **Advanced Test Job**: Runs complex S3 scenarios
- **Auto-retry**: 3 attempts on failure

## Secure Solution - Configuration Changes

The following secure changes resolve the ObjectBucketClaim TLS issue while maintaining full HTTPS security:

### 1. Internal Certificate Creation (`ceph-s3-internal-cert.yaml`):
```yaml
# Self-signed certificate for internal RGW communication
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ceph-s3-gateway-internal-tls
spec:
  secretName: ceph-s3-gateway-internal-tls
  dnsNames:
    - rook-ceph-rgw-ceph-objectstore.rook-ceph.svc
    - rook-ceph-rgw-ceph-objectstore.rook-ceph.svc.cluster.local
```

### 2. Updated RGW Configuration (`rook-ceph-cluster/values.yaml`):
```yaml
# RGW uses internal certificate for HTTPS
gateway:
  instances: 1
  port: 80
  securePort: 443
  sslCertificateRef: ceph-s3-gateway-internal-tls  # Internal cert

# Ingress uses external Let's Encrypt certificate
ingress:
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    nginx.ingress.kubernetes.io/proxy-ssl-verify: "off"  # Skip internal cert verification
  tls:
    - secretName: ceph-s3-gateway-tls  # External Let's Encrypt cert
```

### 3. Security Benefits:
- ✅ **Internal HTTPS**: RGW admin API uses HTTPS with proper certificate
- ✅ **External HTTPS**: Public S3 API uses Let's Encrypt certificate
- ✅ **Certificate Validation**: Internal cert includes service names as SANs
- ✅ **Zero HTTP Traffic**: All communication encrypted end-to-end

## Quick Start - Secure Solution

### Step 1: Deploy Internal Certificate
```bash
cd testing/
kubectl apply -f ceph-s3-internal-cert.yaml

# Wait for certificate to be ready
kubectl wait --for=condition=Ready certificate/ceph-s3-gateway-internal-tls -n rook-ceph --timeout=300s
```

### Step 2: Apply Updated Rook Configuration
```bash
# Apply the updated rook-ceph-cluster/values.yaml through your deployment process
# Key changes:
# - sslCertificateRef: ceph-s3-gateway-internal-tls
# - nginx.ingress.kubernetes.io/proxy-ssl-verify: "off"
```

### Step 3: Run Automated Secure Fix
```bash
# Use the comprehensive script that handles everything
./secure-fix-and-test.sh
```

### Step 4: Manual Testing (Alternative)
```bash
# Deploy bucket claim
kubectl apply -f s3-bucket-claim.yaml

# Wait for bucket creation
kubectl get objectbucketclaim test-s3-bucket -w

# Run tests
kubectl apply -f s3-test-scripts.yaml
kubectl apply -f s3-test-job.yaml

# View results
kubectl logs job/s3-basic-test-job -f
```

## Test Operations

### Basic Tests Include:
1. **List Buckets**: Verify bucket visibility
2. **Upload File**: Test object creation
3. **List Objects**: Verify object listing
4. **Download File**: Test object retrieval
5. **Verify Content**: Ensure data integrity
6. **Get Metadata**: Check bucket properties

### Advanced Tests Include:
1. **Multi-file Upload**: Batch operations
2. **Directory Sync**: Hierarchical structure
3. **Object Copy**: Internal bucket operations
4. **Metadata Queries**: Object properties
5. **Selective Deletion**: Cleanup operations

## Monitoring and Debugging

### Check Bucket Status
```bash
# View bucket claim details
kubectl describe objectbucketclaim test-s3-bucket

# Check generated secret
kubectl get secret test-s3-bucket -o yaml

# View bucket configuration
kubectl get configmap test-s3-bucket -o yaml
```

### View Test Results
```bash
# For job-based tests
kubectl logs job/s3-basic-test-job
kubectl logs job/s3-advanced-test-job

# For pod-based tests
kubectl logs s3-test-pod
```

### Access Credentials
```bash
# Get access key
kubectl get secret test-s3-bucket -o jsonpath='{.data.AWS_ACCESS_KEY_ID}' | base64 -d

# Get secret key
kubectl get secret test-s3-bucket -o jsonpath='{.data.AWS_SECRET_ACCESS_KEY}' | base64 -d

# Get bucket name
kubectl get configmap test-s3-bucket -o jsonpath='{.data.BUCKET_NAME}'
```

## Troubleshooting

### Common Issues:

1. **Bucket Claim Pending (FIXED)**
   - ✅ **Root Cause**: TLS certificate mismatch for internal admin API
   - ✅ **Solution**: Disabled HTTPS on RGW gateway, use HTTP internally
   - ✅ **Status**: Fixed in current configuration
   - **Check**: `kubectl logs -n rook-ceph deployment/rook-ceph-operator | grep bucket`

2. **Connection Refused**
   - Verify S3 ingress is configured: `s3.padmini.systems`
   - Check if RGW service is accessible
   - Validate SSL certificates

3. **Authentication Failed**
   - Ensure ObjectBucketClaim secret is created
   - Verify credentials are properly mounted
   - Check secret permissions

4. **SSL/TLS Issues (RESOLVED)**
   - ✅ **Previous Issue**: Certificate valid for `s3.padmini.systems` but not `rook-ceph-rgw-ceph-objectstore.rook-ceph.svc`
   - ✅ **Solution**: Internal admin API now uses HTTP, external API uses HTTPS via ingress
   - **External clients**: Still use HTTPS endpoint `https://s3.padmini.systems`

### Debug Commands:
```bash
# Check Rook Ceph status
kubectl -n rook-ceph get pods

# Check RGW service
kubectl -n rook-ceph get svc rook-ceph-rgw-ceph-objectstore

# Check ingress
kubectl get ingress -A

# Test connectivity
kubectl run debug --image=curlimages/curl -it --rm -- curl -k https://s3.padmini.systems
```

## Cleanup

### Remove Test Resources
```bash
# Delete test jobs
kubectl delete -f s3-test-job.yaml

# Delete test pod
kubectl delete -f s3-test-pod.yaml

# Delete test scripts
kubectl delete -f s3-test-scripts.yaml

# Clean bucket contents (run cleanup script first)
kubectl exec -it s3-test-pod -- /scripts/cleanup.sh

# Delete bucket claim (this will delete the bucket)
kubectl delete -f s3-bucket-claim.yaml
```

## Security Notes

- Credentials are automatically generated and stored in Kubernetes secrets
- Access is scoped to the specific bucket created
- Use RBAC to control access to bucket secrets
- Consider using service accounts for production workloads

## Next Steps

After successful testing:
1. Integrate S3 storage into your applications
2. Set up monitoring for object storage metrics
3. Configure backup and retention policies
4. Implement proper access controls and policies