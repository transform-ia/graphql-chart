# Testing Guide for GraphQL Chart

## Local Testing (Before Committing)

### 1. Helm Lint

```bash
# Get Claude pod name
POD=$(kubectl get pod -n claude -l app=claude-code -o jsonpath='{.items[0].metadata.name}')

# Lint the chart
kubectl exec -n claude $POD -c helm -- \
  helm lint /workspace/sandbox/graphql-chart

# Strict linting
kubectl exec -n claude $POD -c helm -- \
  helm lint /workspace/sandbox/graphql-chart --strict
```

### 2. Template Rendering

```bash
# Render with default values
kubectl exec -n claude $POD -c helm -- \
  helm template my-graphql /workspace/sandbox/graphql-chart

# Render with custom values
kubectl exec -n claude $POD -c helm -- \
  helm template test-release /workspace/sandbox/graphql-chart \
  --set postgresql.clusterName=test-cluster \
  --set hasura.env.adminSecret=testsecret
```

### 3. Validate Against Kubernetes API

```bash
# Dry-run apply to validate resource definitions
kubectl exec -n claude $POD -c helm -- \
  helm template my-graphql /workspace/sandbox/graphql-chart | \
  kubectl apply --dry-run=client -f -
```

## Testing Specific Components

### Database URL Generation

```bash
# Check generated database URLs
kubectl exec -n claude $POD -c helm -- \
  helm template test /workspace/sandbox/graphql-chart | \
  grep "HASURA_GRAPHQL_DATABASE_URL" -A 1

# Should output:
# - name: HASURA_GRAPHQL_DATABASE_URL
#   value: "postgres://graphql:changeme@postgres-rw.graphql-dev.svc.cluster.local:5432/test"
```

### Database CRD Names

```bash
# Check Database CRD specs
kubectl exec -n claude $POD -c helm -- \
  helm template my-release /workspace/sandbox/graphql-chart | \
  grep -A 5 "kind: Database"

# Verify:
# - Data database name matches release name
# - Metadata database name is <release>-hasura
# - Owner is set correctly
```

### PostgreSQL Sidecar Environment

```bash
# Check psql environment variables
kubectl exec -n claude $POD -c helm -- \
  helm template test /workspace/sandbox/graphql-chart | \
  grep -A 20 "# PostgreSQL CLI sidecar" | grep -E "name: PG|value:"

# Verify all PG* environment variables are set:
# - PGHOST
# - PGPORT
# - PGDATABASE
# - PGUSER
# - PGPASSWORD
```

### Network Policies

```bash
# Check network policy creation
kubectl exec -n claude $POD -c helm -- \
  helm template test /workspace/sandbox/graphql-chart | \
  grep "kind: NetworkPolicy" -A 3

# Should create 4 policies:
# 1. allow-dns
# 2. allow-https-egress
# 3. allow-ingress
# 4. allow-postgres
```

## Integration Testing (After Deployment)

### Prerequisites Setup

```bash
# 1. Ensure PostgreSQL cluster exists
kubectl get cluster -n graphql-dev postgres

# 2. If not, create one (example)
kubectl apply -f - <<EOF
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgres
  namespace: graphql-dev
spec:
  instances: 1
  storage:
    size: 1Gi
EOF
```

### Deploy Chart

```bash
# Deploy to test namespace
helm install test-graphql /workspace/sandbox/graphql-chart \
  --namespace graphql-dev \
  --create-namespace

# Watch pod startup
kubectl get pods -n graphql-dev -w
```

### Verify Deployment

```bash
# 1. Check all resources created
kubectl get all,database,networkpolicy -n graphql-dev

# 2. Check Database CRDs
kubectl get database -n graphql-dev
# Should show:
# - test-graphql-graphql-chart-data
# - test-graphql-graphql-chart-metadata

# 3. Check pod is running
POD=$(kubectl get pod -n graphql-dev \
  -l app.kubernetes.io/instance=test-graphql \
  -o jsonpath='{.items[0].metadata.name}')

kubectl get pod $POD -n graphql-dev
# Should be: 2/2 Running
```

### Test Hasura Console Access

```bash
# Port forward
kubectl port-forward -n graphql-dev svc/test-graphql-graphql-chart 8080:8080 &

# Test HTTP endpoint
curl http://localhost:8080/healthz

# Should return: OK
```

### Test PostgreSQL CLI Access

```bash
# Test psql environment variables
kubectl exec -n graphql-dev $POD -c psql -- env | grep PG

# Test psql connection
kubectl exec -n graphql-dev $POD -c psql -- psql -c '\l'

# Should list databases including:
# - test-graphql (data database)
# - test-graphql-hasura (metadata database)
```

### Test Database Connectivity from Hasura

```bash
# Check Hasura logs for successful connection
kubectl logs -n graphql-dev $POD -c hasura | grep -i "database"

# Should see messages about metadata database initialization
```

## Cleanup After Testing

```bash
# Uninstall the release
helm uninstall test-graphql -n graphql-dev

# Verify cleanup
kubectl get all -n graphql-dev

# Note: Database CRDs may need manual cleanup
kubectl delete database -n graphql-dev --all

# Optional: Delete namespace
kubectl delete namespace graphql-dev
```

## Testing Custom Values

### Test with Different PostgreSQL Cluster

```bash
cat > test-values.yaml <<EOF
postgresql:
  clusterName: my-test-cluster
  service: my-test-cluster-rw
  user: testuser
  password: testpass
EOF

kubectl exec -n claude $POD -c helm -- \
  helm template test /workspace/sandbox/graphql-chart \
  -f /workspace/sandbox/graphql-chart/test-values.yaml | \
  grep "HASURA_GRAPHQL_DATABASE_URL" -A 1
```

### Test with Custom Database Names

```bash
kubectl exec -n claude $POD -c helm -- \
  helm template test /workspace/sandbox/graphql-chart \
  --set postgresql.dataDatabase=myapp \
  --set postgresql.metadataDatabase=myapp-meta | \
  grep -E "spec:" -A 2 | grep "name:"
```

### Test with Disabled Features

```bash
# Disable psql sidecar
kubectl exec -n claude $POD -c helm -- \
  helm template test /workspace/sandbox/graphql-chart \
  --set psqlSidecar.enabled=false | \
  grep -c "name: psql"

# Should return: 0

# Disable network policies
kubectl exec -n claude $POD -c helm -- \
  helm template test /workspace/sandbox/graphql-chart \
  --set networkPolicies.enabled=false | \
  grep -c "kind: NetworkPolicy"

# Should return: 0
```

## GitHub Actions Testing

After pushing to GitHub, verify:

### 1. Linting Job

```bash
# Monitor workflow run
gh run list --repo transform-ia/graphql-chart

# View logs if failed
gh run view <run-id> --log-failed
```

### 2. Package and Push (on git tags)

```bash
# After creating a tag (e.g., v0.0.1)
git tag v0.0.1
git push origin v0.0.1

# Monitor the build
gh run watch

# Verify chart published to GHCR
# Visit: https://github.com/orgs/transform-ia/packages
```

## Common Test Scenarios

### Scenario 1: Multi-Release Testing

```bash
# Deploy multiple releases with different configs
helm install app1 /workspace/sandbox/graphql-chart \
  --set postgresql.dataDatabase=app1-db

helm install app2 /workspace/sandbox/graphql-chart \
  --set postgresql.dataDatabase=app2-db

# Verify isolation
kubectl get database -n graphql-dev
# Should show separate databases for each release
```

### Scenario 2: Upgrade Testing

```bash
# Install v1
helm install test /workspace/sandbox/graphql-chart

# Modify values
# Upgrade
helm upgrade test /workspace/sandbox/graphql-chart \
  --set hasura.env.enableConsole=false

# Verify changes applied
kubectl describe deployment test-graphql-chart -n graphql-dev | \
  grep "HASURA_GRAPHQL_ENABLE_CONSOLE"
```

### Scenario 3: Rollback Testing

```bash
# Install
helm install test /workspace/sandbox/graphql-chart

# Upgrade with breaking change
helm upgrade test /workspace/sandbox/graphql-chart \
  --set hasura.image.tag=invalid-tag

# Rollback
helm rollback test

# Verify rollback succeeded
kubectl get pods -n graphql-dev
```

## Performance Testing

### Resource Usage

```bash
# Monitor resource usage
kubectl top pod -n graphql-dev

# Check resource limits
kubectl describe pod $POD -n graphql-dev | grep -A 10 "Limits:"
```

### Startup Time

```bash
# Time from deployment to ready
time helm install test /workspace/sandbox/graphql-chart && \
  kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/instance=test \
  -n graphql-dev \
  --timeout=300s
```

## Expected Results Summary

| Test | Expected Result |
|------|----------------|
| Helm lint | 0 failures, 1 info (icon recommended) |
| Template render | Valid YAML output |
| Database URL | postgres://user:pass@host:5432/db |
| Database CRDs | 2 created (data + metadata) |
| Pod containers | 2/2 (hasura + psql) |
| Network policies | 4 created |
| Healthz endpoint | Returns "OK" |
| psql connection | Successfully connects |
