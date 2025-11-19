# GraphQL Chart

Helm chart for deploying a complete GraphQL development environment with Hasura GraphQL Engine and CloudNativePG
PostgreSQL integration.

## Overview

This chart deploys:

- **Hasura GraphQL Engine**: Auto-generates GraphQL APIs from PostgreSQL databases
- **PostgreSQL Sidecar**: psql CLI container for easy database access
- **CloudNativePG Integration**: Automatic database creation via Database CRDs
- **Network Policies**: Secure pod communication
- **RBAC**: Namespace-scoped permissions

## Prerequisites

- Kubernetes 1.24+
- Helm 3.16+
- **CloudNativePG PostgreSQL Operator** (required)
- A CloudNativePG PostgreSQL cluster (referenced in values)

## Installation

### Quick Start

```bash
# Add chart repository (once published)
helm repo add transform-ia https://ghcr.io/transform-ia

# Install with default values
helm install my-graphql oci://ghcr.io/transform-ia/graphql-chart --version 0.0.1

# Or install from local directory
helm install my-graphql .
```

### Custom Installation

```bash
# Create custom values file
cat > my-values.yaml <<EOF
global:
  namespace: my-namespace

postgresql:
  clusterName: my-postgres-cluster
  user: myuser
  password: "secure-password-here"

hasura:
  env:
    adminSecret: "my-secure-admin-secret"
EOF

# Install with custom values
helm install my-graphql . -f my-values.yaml
```

## Configuration

### Global Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.namespace` | Target namespace | `graphql-dev` |
| `global.timezone` | Timezone | `America/Montreal` |

### Hasura Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `hasura.image.repository` | Hasura image | `hasura/graphql-engine` |
| `hasura.image.tag` | Image tag (defaults to Chart.AppVersion) | `""` |
| `hasura.port` | Hasura HTTP port | `8080` |
| `hasura.env.adminSecret` | Admin secret for console/API | `myadminsecret` |
| `hasura.env.enableConsole` | Enable GraphQL console | `true` |
| `hasura.env.devMode` | Enable dev mode | `true` |
| `hasura.env.enableTelemetry` | Enable telemetry | `false` |

### PostgreSQL Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `postgresql.clusterName` | CloudNativePG cluster name | `postgres` |
| `postgresql.service` | PostgreSQL service name | `postgres-rw` |
| `postgresql.port` | PostgreSQL port | `5432` |
| `postgresql.user` | Database user | `graphql` |
| `postgresql.password` | Database password | `changeme` |
| `postgresql.dataDatabase` | Data database name (defaults to release name) | `""` |
| `postgresql.metadataDatabase` | Metadata database name | `"<release>-hasura"` |
| `postgresql.createDatabases` | Create Database CRDs | `true` |

### PostgreSQL CLI Sidecar

| Parameter | Description | Default |
|-----------|-------------|---------|
| `psqlSidecar.enabled` | Enable psql CLI sidecar | `true` |
| `psqlSidecar.image.repository` | PostgreSQL image | `postgres` |
| `psqlSidecar.image.tag` | Image tag | `16-alpine` |

## Usage

### Accessing Hasura Console

```bash
# Port forward to Hasura
kubectl port-forward -n graphql-dev svc/my-graphql-graphql-chart 8080:8080

# Open browser to http://localhost:8080/console
# Admin secret header: x-hasura-admin-secret: myadminsecret
```

### Using PostgreSQL CLI

The chart includes a PostgreSQL sidecar container pre-configured for psql access:

```bash
# Get pod name
POD=$(kubectl get pod -n graphql-dev \
  -l app.kubernetes.io/instance=my-graphql \
  -o jsonpath='{.items[0].metadata.name}')

# Connect to data database (automatic via PGDATABASE env var)
kubectl exec -it $POD -n graphql-dev -c psql -- psql

# Connect to metadata database
kubectl exec -it $POD -n graphql-dev -c psql -- psql -d my-graphql-hasura
```

Environment variables are pre-configured:

- `PGHOST`: PostgreSQL service hostname
- `PGPORT`: `5432`
- `PGDATABASE`: Data database name (default connection)
- `PGUSER`: Database user
- `PGPASSWORD`: Database password

### GraphQL Endpoint

The GraphQL API is available at:

```
http://<release>-graphql-chart.<namespace>.svc.cluster.local:8080/v1/graphql
```

For external access, create an Ingress:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hasura-ingress
  namespace: graphql-dev
spec:
  rules:
    - host: hasura.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-graphql-graphql-chart
                port:
                  number: 8080
```

## Architecture

### Database Structure

The chart creates two PostgreSQL databases via CloudNativePG Database CRDs:

1. **Data Database**: For your application data
   - Name: `<release-name>` (configurable)
   - Owner: `<postgresql.user>`

2. **Metadata Database**: For Hasura internal state
   - Name: `<release-name>-hasura` (configurable)
   - Owner: `<postgresql.user>`

Both databases are owned by the same user specified in `postgresql.user`.

### Container Structure

- **hasura**: Main Hasura GraphQL Engine container
  - Port 8080 (HTTP)
  - Health checks on `/healthz`
  - Read-only root filesystem

- **psql**: PostgreSQL CLI sidecar (optional)
  - Pre-configured environment for psql
  - Minimal resource footprint
  - Read-only root filesystem

## Security Considerations

### Production Deployment

**CRITICAL**: Change default credentials before production:

```yaml
hasura:
  env:
    adminSecret: "use-a-strong-random-secret"

postgresql:
  password: "use-a-strong-database-password"
```

**Better approach**: Use external secret management:

- Sealed Secrets
- External Secrets Operator
- HashiCorp Vault
- Cloud provider secret managers

### Network Policies

The chart includes network policies to:

- Allow DNS resolution (kube-system)
- Allow HTTPS egress (for webhooks/actions)
- Allow PostgreSQL database access
- Allow ingress from specified sources (Claude Code, Ingress controller)

Customize in `values.yaml`:

```yaml
networkPolicies:
  enabled: true
  allowHTTPSEgress: true
  allowIngressFrom:
    - app: claude-code
    - app: ingress-nginx
```

### Security Hardening

The chart enforces:

- Read-only root filesystem
- Non-root user (UID 999)
- Dropped capabilities
- Seccomp profile (RuntimeDefault)
- No privilege escalation

## Development

### Local Testing

```bash
# Get pod name
POD=$(kubectl get pod -n claude -l app=claude-code -o jsonpath='{.items[0].metadata.name}')

# Render templates
kubectl exec -n claude $POD -c helm -- \
  helm template my-graphql /workspace/sandbox/graphql-chart

# Lint chart
kubectl exec -n claude $POD -c helm -- \
  helm lint /workspace/sandbox/graphql-chart

# Test with custom values
kubectl exec -n claude $POD -c helm -- \
  helm template my-graphql /workspace/sandbox/graphql-chart \
  --set postgresql.clusterName=test-cluster
```

### CI/CD Pipeline

The chart includes GitHub Actions workflows for:

1. **Linting** (on push/PR):
   - YAML linting (yamllint)
   - Markdown linting (markdownlint)

2. **Package and Push** (on git tags):
   - Package Helm chart
   - Publish to GitHub Container Registry (GHCR)

#### Release Process

```bash
# 1. Update Chart.yaml version (if needed for chart changes)
# 2. Commit all changes
git add .
git commit -m "Release version 0.0.2"
git push

# 3. Create and push git tag
git tag v0.0.2
git push origin v0.0.2

# 4. GitHub Actions will automatically:
#    - Lint the chart
#    - Package the chart
#    - Push to oci://ghcr.io/transform-ia/graphql-chart:0.0.2
```

## Troubleshooting

### Hasura Won't Start

Check database connectivity:

```bash
# Check pod logs
kubectl logs -n graphql-dev <pod-name> -c hasura

# Common issues:
# - PostgreSQL cluster not ready
# - Database CRDs not created
# - Incorrect database credentials
```

### Database Connection Issues

Verify CloudNativePG setup:

```bash
# Check PostgreSQL cluster
kubectl get cluster -n graphql-dev

# Check Database CRDs
kubectl get database -n graphql-dev

# Check PostgreSQL service
kubectl get svc -n graphql-dev postgres-rw
```

### Network Policy Blocking Access

Temporarily disable to test:

```bash
helm upgrade my-graphql . --set networkPolicies.enabled=false
```

## Examples

### Minimal Production Setup

```yaml
global:
  namespace: production

hasura:
  image:
    tag: "v2.40.0"  # Pin specific version
  env:
    adminSecret: ""  # Use secretRef instead
    enableConsole: "false"
    devMode: "false"

postgresql:
  clusterName: prod-postgres
  user: hasura_prod
  password: ""  # Use secretRef instead

psqlSidecar:
  enabled: false  # Disable in production

resources:
  limits:
    cpu: 1000m
    memory: 2Gi
  requests:
    cpu: 250m
    memory: 512Mi
```

### Multi-Environment Setup

```bash
# Development
helm install graphql-dev . -f values-dev.yaml

# Staging
helm install graphql-staging . -f values-staging.yaml

# Production
helm install graphql-prod . -f values-prod.yaml
```

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run linting and tests
5. Submit a pull request

## License

MIT License - see repository for details

## Support

- Issues: https://github.com/transform-ia/graphql-chart/issues
- Documentation: https://hasura.io/docs/
- CloudNativePG: https://cloudnative-pg.io/
