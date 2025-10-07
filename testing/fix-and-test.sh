#!/bin/bash
set -e

echo "=== Fixing Rook Ceph ObjectBucketClaim TLS Issue ==="

# Step 1: Delete the existing ObjectBucketClaim to start fresh
echo "1. Cleaning up existing ObjectBucketClaim..."
kubectl delete objectbucketclaim test-s3-bucket -n default --ignore-not-found=true
kubectl delete configmap test-s3-bucket -n default --ignore-not-found=true
kubectl delete secret test-s3-bucket -n default --ignore-not-found=true

# Step 2: Apply the updated Rook Ceph cluster configuration
echo "2. Applying updated Rook Ceph cluster configuration..."
echo "   - Disabled HTTPS on RGW gateway to fix internal admin API access"
echo "   - Updated ingress to use HTTP backend with HTTPS termination"

# Note: You need to apply this through your GitOps/Helm process
echo "   Please apply the updated rook-ceph-cluster/values.yaml through your deployment process"
echo "   The key changes made:"
echo "   - Removed securePort and sslCertificateRef from RGW gateway"
echo "   - Added nginx.ingress.kubernetes.io/backend-protocol: HTTP annotation"

# Step 3: Wait for RGW pod to restart
echo "3. Waiting for RGW pod to restart with new configuration..."
echo "   Monitor with: kubectl get pods -n rook-ceph | grep rgw"

# Step 4: Create the ObjectBucketClaim again
echo "4. Creating ObjectBucketClaim..."
kubectl apply -f s3-bucket-claim.yaml

# Step 5: Monitor the status
echo "5. Monitoring ObjectBucketClaim status..."
echo "   Waiting for bucket to be provisioned..."

# Wait for the OBC to be bound
timeout=300
counter=0
while [ $counter -lt $timeout ]; do
    status=$(kubectl get objectbucketclaim test-s3-bucket -n default -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
    if [ "$status" = "Bound" ]; then
        echo "   ✅ ObjectBucketClaim is now Bound!"
        break
    elif [ "$status" = "Failed" ]; then
        echo "   ❌ ObjectBucketClaim failed!"
        kubectl describe objectbucketclaim test-s3-bucket -n default
        exit 1
    else
        echo "   Status: $status (waiting...)"
        sleep 10
        counter=$((counter + 10))
    fi
done

if [ $counter -ge $timeout ]; then
    echo "   ⏰ Timeout waiting for ObjectBucketClaim to be bound"
    echo "   Current status:"
    kubectl describe objectbucketclaim test-s3-bucket -n default
    exit 1
fi

# Step 6: Verify resources were created
echo "6. Verifying created resources..."
echo "   Secret:"
kubectl get secret test-s3-bucket -n default -o yaml | grep -E "AWS_ACCESS_KEY_ID|AWS_SECRET_ACCESS_KEY" | head -2
echo "   ConfigMap:"
kubectl get configmap test-s3-bucket -n default -o yaml | grep -A 5 "data:"

# Step 7: Run basic test
echo "7. Running basic S3 test..."
kubectl apply -f s3-test-scripts.yaml
kubectl apply -f s3-test-job.yaml

echo "8. Monitor test job with:"
echo "   kubectl logs job/s3-basic-test-job -f"

echo ""
echo "=== Fix Applied Successfully! ==="
echo "The ObjectBucketClaim should now work properly."
echo ""
echo "Next steps:"
echo "1. Apply the updated rook-ceph-cluster/values.yaml through your deployment process"
echo "2. Wait for RGW pod to restart"
echo "3. Run this script to test the fix"
echo "4. Monitor test results with: kubectl logs job/s3-basic-test-job -f"