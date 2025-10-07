# S3 Bucket Testing with Rook Ceph

This directory contains comprehensive testing manifests for S3 bucket functionality using Rook Ceph Object Storage (RGW).

## Prerequisites

- Rook Ceph cluster deployed and running
- Object storage (RGW) configured with `ceph-objectstore`
- Storage class `ceph-bucket` available
- Ingress configured for S3 endpoint: `s3.padmini.systems`

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

## Quick Start

### Step 1: Deploy the Bucket Claim
```bash
kubectl apply -f s3-bucket-claim.yaml
```

### Step 2: Wait for Bucket Creation
```bash
# Check if bucket claim is bound
kubectl get objectbucketclaim test-s3-bucket

# Check if secret and configmap are created
kubectl get secret test-s3-bucket
kubectl get configmap test-s3-bucket
```

### Step 3: Deploy Test Scripts
```bash
kubectl apply -f s3-test-scripts.yaml
```

### Step 4: Run Basic Tests (Choose one method)

#### Method A: Using Test Job (Automated)
```bash
kubectl apply -f s3-test-job.yaml

# Check job status
kubectl get jobs

# View test results
kubectl logs job/s3-basic-test-job
```

#### Method B: Using Interactive Pod (Manual)
```bash
kubectl apply -f s3-test-pod.yaml

# Wait for pod to be ready
kubectl wait --for=condition=Ready pod/s3-test-pod

# Execute tests manually
kubectl exec -it s3-test-pod -- /scripts/test-basic-operations.sh
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

1. **Bucket Claim Pending**
   - Check if Rook Ceph cluster is healthy
   - Verify `ceph-bucket` storage class exists
   - Check RGW pods are running

2. **Connection Refused**
   - Verify S3 ingress is configured: `s3.padmini.systems`
   - Check if RGW service is accessible
   - Validate SSL certificates

3. **Authentication Failed**
   - Ensure ObjectBucketClaim secret is created
   - Verify credentials are properly mounted
   - Check secret permissions

4. **SSL/TLS Issues**
   - For self-signed certificates, add `--no-verify-ssl` to AWS CLI commands
   - Check certificate configuration in ingress

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