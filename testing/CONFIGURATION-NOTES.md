# Configuration Notes and Corrections

## Incorrect AWS Annotation Removed

### What was wrong:
```yaml
# INCORRECT - This was removed:
service:
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-ssl-cert: ceph-s3-gateway-internal-tls
```

### Why it was wrong:
1. **AWS-specific annotation**: Only works with AWS Load Balancer Controller on EKS
2. **Your environment**: kubeadm cluster with NGINX ingress controller
3. **Certificate type mismatch**: Expects AWS Certificate Manager (ACM) certificates, not Kubernetes secrets
4. **No effect**: This annotation is completely ignored in non-AWS environments

### Correct configuration:
```yaml
# CORRECT - Clean configuration:
gateway:
  instances: 1
  port: 80
  securePort: 443
  sslCertificateRef: ceph-s3-gateway-internal-tls  # This is the right way
```

## How SSL/TLS Works in Your Setup

### Internal RGW Gateway:
- **Certificate**: `ceph-s3-gateway-internal-tls` (self-signed with internal service names)
- **Configuration**: `sslCertificateRef` field in gateway spec
- **Purpose**: Secure internal admin API communication for ObjectBucketClaim

### External Ingress:
- **Certificate**: `ceph-s3-gateway-tls` (Let's Encrypt for s3.padmini.systems)
- **Configuration**: `tls.secretName` in ingress spec
- **Purpose**: Secure external S3 API access

### NGINX Ingress Annotations:
```yaml
nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"     # Backend uses HTTPS
nginx.ingress.kubernetes.io/proxy-ssl-verify: "off"      # Skip internal cert verification
```

## Key Differences: AWS vs Your Setup

| Component | AWS EKS | Your kubeadm Cluster |
|-----------|---------|----------------------|
| Load Balancer | AWS ALB/NLB | NGINX Ingress |
| Certificate Manager | AWS ACM | cert-manager |
| SSL Termination | AWS Load Balancer | NGINX Ingress |
| Internal Communication | AWS annotations | Kubernetes secrets |

## Verification Commands

### Check RGW is using correct certificate:
```bash
kubectl get pods -n rook-ceph -l app=rook-ceph-rgw -o yaml | grep -A 5 -B 5 "ceph-s3-gateway-internal-tls"
```

### Verify certificate contents:
```bash
kubectl get secret ceph-s3-gateway-internal-tls -n rook-ceph -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout | grep -A 5 "Subject Alternative Name"
```

### Test internal HTTPS connectivity:
```bash
kubectl run test-internal --image=curlimages/curl --rm -it --restart=Never -- \
  curl -k -v https://rook-ceph-rgw-ceph-objectstore.rook-ceph.svc/
```

The configuration is now clean and correct for your kubeadm + NGINX ingress environment.