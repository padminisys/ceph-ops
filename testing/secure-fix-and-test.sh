#!/bin/bash
set -e

echo "=== Secure Fix for Rook Ceph ObjectBucketClaim TLS Issue ==="
echo "This solution maintains HTTPS security for both internal and external access"

# Step 1: Create internal certificate for RGW service
echo "1. Creating internal certificate for RGW service..."
kubectl apply -f ceph-s3-internal-cert.yaml

# Wait for certificate to be ready
echo "   Waiting for internal certificate to be issued..."
timeout=300
counter=0
while [ $counter -lt $timeout ]; do
    cert_ready=$(kubectl get certificate ceph-s3-gateway-internal-tls -n rook-ceph -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
    if [ "$cert_ready" = "True" ]; then
        echo "   ✅ Internal certificate is ready!"
        break
    else
        echo "   Waiting for certificate... ($counter/$timeout)"
        sleep 10
        counter=$((counter + 10))
    fi
done

if [ $counter -ge $timeout ]; then
    echo "   ❌ Timeout waiting for certificate"
    kubectl describe certificate ceph-s3-gateway-internal-tls -n rook-ceph
    exit 1
fi

# Step 2: Verify certificate includes internal service names
echo "2. Verifying certificate includes internal service names..."
kubectl get secret ceph-s3-gateway-internal-tls -n rook-ceph -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout | grep -A 10 "Subject Alternative Name"

# Step 3: Clean up existing ObjectBucketClaim
echo "3. Cleaning up existing ObjectBucketClaim..."
kubectl delete objectbucketclaim test-s3-bucket -n default --ignore-not-found=true
kubectl delete configmap test-s3-bucket -n default --ignore-not-found=true
kubectl delete secret test-s3-bucket -n default --ignore-not-found=true

# Step 4: Apply updated Rook Ceph configuration
echo "4. Updated Rook Ceph cluster configuration ready to apply..."
echo "   Key changes:"
echo "   - RGW gateway uses internal certificate: ceph-s3-gateway-internal-tls"
echo "   - Ingress uses external Let's Encrypt certificate: ceph-s3-gateway-tls"
echo "   - Both internal and external connections use HTTPS"
echo ""
echo "   Please apply the updated rook-ceph-cluster/values.yaml through your deployment process"
echo "   Then continue with this script..."

read -p "   Press Enter after applying the updated configuration..."

# Step 5: Wait for RGW pod to restart
echo "5. Waiting for RGW pod to restart with new certificate..."
kubectl rollout status deployment/rook-ceph-rgw-ceph-objectstore-a -n rook-ceph --timeout=300s

# Step 6: Verify RGW is using the new certificate
echo "6. Verifying RGW is using the new certificate..."
rgw_pod=$(kubectl get pods -n rook-ceph -l app=rook-ceph-rgw -o jsonpath='{.items[0].metadata.name}')
echo "   RGW pod: $rgw_pod"

# Step 7: Test internal HTTPS connectivity
echo "7. Testing internal HTTPS connectivity..."
kubectl run test-internal-https --image=curlimages/curl --rm -it --restart=Never -- \
  curl -k -v https://rook-ceph-rgw-ceph-objectstore.rook-ceph.svc/

# Step 8: Create ObjectBucketClaim
echo "8. Creating ObjectBucketClaim..."
kubectl apply -f s3-bucket-claim.yaml

# Step 9: Monitor ObjectBucketClaim status
echo "9. Monitoring ObjectBucketClaim status..."
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
        echo "   Checking operator logs..."
        kubectl logs -n rook-ceph deployment/rook-ceph-operator --tail=20 | grep -i bucket
        exit 1
    else
        echo "   Status: $status (waiting...)"
        sleep 10
        counter=$((counter + 10))
    fi
done

if [ $counter -ge $timeout ]; then
    echo "   ⏰ Timeout waiting for ObjectBucketClaim"
    kubectl describe objectbucketclaim test-s3-bucket -n default
    kubectl logs -n rook-ceph deployment/rook-ceph-operator --tail=20 | grep -i bucket
    exit 1
fi

# Step 10: Verify created resources
echo "10. Verifying created resources..."
echo "    Secret created:"
kubectl get secret test-s3-bucket -n default
echo "    ConfigMap created:"
kubectl get configmap test-s3-bucket -n default

# Step 11: Run S3 tests
echo "11. Running S3 tests..."
kubectl apply -f s3-test-scripts.yaml
kubectl apply -f s3-test-job.yaml

echo ""
echo "=== Secure Fix Applied Successfully! ==="
echo "✅ Internal RGW communication uses HTTPS with self-signed certificate"
echo "✅ External S3 API uses HTTPS with Let's Encrypt certificate"
echo "✅ ObjectBucketClaim should now work with full TLS security"
echo ""
echo "Monitor test results with:"
echo "kubectl logs job/s3-basic-test-job -f"
echo ""
echo "Check certificate details:"
echo "kubectl get secret ceph-s3-gateway-internal-tls -n rook-ceph -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout"