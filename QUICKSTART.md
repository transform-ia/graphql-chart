# GraphQL Chart Quick Start

## Prerequisites Checklist

- [ ] CloudNativePG PostgreSQL Operator installed
- [ ] PostgreSQL Cluster created (default name: `postgres`)
- [ ] Kubernetes 1.24+
- [ ] Helm 3.16+

## 5-Minute Setup

### 1. Install the Chart

```bash
# From local directory
helm install my-graphql /workspace/sandbox/graphql-chart

# Or with custom values
helm install my-graphql /workspace/sandbox/graphql-chart \
  --set hasura.env.adminSecret=myCustomSecret \
  --set postgresql.password=securePassword
```

### 2. Verify Installation

```bash
# Check pod status
kubectl get pods -n graphql-dev

# Should show:
# NAME                              READY   STATUS    RESTARTS   AGE
# my-graphql-graphql-chart-xxx      2/2     Running   0          1m
```

### 3. Access Hasura Console

```bash
# Port forward
kubectl port-forward -n graphql-dev svc/my-graphql-graphql-chart 8080:8080

# Open browser: http://localhost:8080/console
# Header: x-hasura-admin-secret: myadminsecret
```

### 4. Access PostgreSQL CLI

```bash
# Get pod name
POD=$(kubectl get pod -n graphql-dev \
  -l app.kubernetes.io/instance=my-graphql \
  -o jsonpath='{.items[0].metadata.name}')

# Connect to database
kubectl exec -it $POD -n graphql-dev -c psql -- psql

# You're now in psql connected to the data database!
```

## Common Operations

### View Database Configuration

```bash
kubectl exec -it $POD -n graphql-dev -c psql -- env | grep PG
```

### Switch to Metadata Database

```bash
kubectl exec -it $POD -n graphql-dev -c psql -- psql -d my-graphql-hasura
```

### Check Hasura Logs

```bash
kubectl logs -n graphql-dev $POD -c hasura
```

## Customization Examples

### Production Setup

```yaml
# production-values.yaml
hasura:
  image:
    tag: "v2.40.0"
  env:
    adminSecret: "use-external-secret-manager"
    enableConsole: "false"
    devMode: "false"

postgresql:
  clusterName: prod-postgres
  user: hasura_prod
  password: "use-external-secret-manager"

resources:
  limits:
    cpu: 1000m
    memory: 2Gi
  requests:
    cpu: 250m
    memory: 512Mi
```

### Different PostgreSQL Cluster

```bash
helm install my-graphql /workspace/sandbox/graphql-chart \
  --set postgresql.clusterName=my-cluster \
  --set postgresql.service=my-cluster-rw
```

### Custom Database Names

```bash
helm install my-graphql /workspace/sandbox/graphql-chart \
  --set postgresql.dataDatabase=myapp \
  --set postgresql.metadataDatabase=myapp-metadata
```

## Troubleshooting

### Pod Not Starting

```bash
# Check events
kubectl describe pod $POD -n graphql-dev

# Common issues:
# - PostgreSQL cluster not ready
# - Database CRDs not created
# - Network policy blocking access
```

### Database Connection Failed

```bash
# Verify PostgreSQL cluster
kubectl get cluster -n graphql-dev postgres

# Verify Database CRDs
kubectl get database -n graphql-dev

# Check PostgreSQL service
kubectl get svc -n graphql-dev postgres-rw
```

### Can't Access Console

```bash
# Check if port-forward is running
lsof -i :8080

# Verify service
kubectl get svc -n graphql-dev

# Check pod logs
kubectl logs -n graphql-dev $POD -c hasura
```

## Next Steps

1. Track PostgreSQL tables in Hasura console
2. Create GraphQL queries and mutations
3. Set up authentication and permissions
4. Configure webhooks and actions
5. Add Ingress for external access

## Resources

- Full README: `/workspace/sandbox/graphql-chart/README.md`
- Hasura Docs: https://hasura.io/docs/
- CloudNativePG Docs: https://cloudnative-pg.io/
