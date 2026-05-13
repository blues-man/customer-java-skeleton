---
name: postgres-k8s
description: >-
  This skill should be used when the user asks to "deploy postgres to
  kubernetes", "install postgres on k8s", "create postgres database on
  kubernetes", "set up postgresql for kubernetes", "deploy database to k8s",
  or needs to provision a PostgreSQL database on Kubernetes for this application.
---

# Deploy PostgreSQL to Kubernetes

Deploy a PostgreSQL 15 database to Kubernetes for the customer application. This creates a Deployment running the Red Hat RHEL9 PostgreSQL 15 image and a ClusterIP Service to expose it within the cluster.

## Prerequisites

Before proceeding, verify:

1. `kubectl` CLI is installed and configured to a cluster (`kubectl cluster-info`)
2. A namespace exists or can be created (`kubectl get namespaces`)
3. The cluster can pull from `registry.redhat.io` (or the user has an alternative PostgreSQL image)

## Deployment Workflow

### Step 1: Select or Create the Namespace

```bash
kubectl create namespace <namespace> || kubectl get namespace <namespace>
kubectl config set-context --current --namespace=<namespace>
```

If the user does not specify a namespace, suggest one derived from the app name (e.g., `customer-app`).

### Step 2: Apply the PostgreSQL Deployment

Create or apply the following manifest as `deployment/kubernetes/postgres/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgresql-customer
  labels:
    app: postgresql-customer
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgresql-customer
  template:
    metadata:
      labels:
        app: postgresql-customer
    spec:
      containers:
        - name: postgresql
          image: registry.redhat.io/rhel9/postgresql-15
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 5432
              protocol: TCP
              name: postgres-cust
          env:
            - name: POSTGRESQL_USER
              value: customer
            - name: POSTGRESQL_PASSWORD
              value: customer
            - name: POSTGRESQL_ADMIN_PASSWORD
              value: postgres
            - name: POSTGRESQL_DATABASE
              value: fantaco_customer
          volumeMounts:
            - name: postgres-customer-data
              mountPath: /var/lib/postgresql/data
      volumes:
        - name: postgres-customer-data
          emptyDir: {}
```

Apply it:

```bash
kubectl apply -f deployment/kubernetes/postgres/deployment.yaml
```

Wait for the pod to be ready:

```bash
kubectl rollout status deployment/postgresql-customer --timeout=120s
```

### Step 3: Apply the PostgreSQL Service

Create or apply the following manifest as `deployment/kubernetes/postgres/service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgres-cust
  labels:
    app: postgres-cust
spec:
  type: ClusterIP
  ports:
    - port: 5432
      targetPort: postgres-cust
      protocol: TCP
      name: postgres-cust
  selector:
    app: postgresql-customer
```

Apply it:

```bash
kubectl apply -f deployment/kubernetes/postgres/service.yaml
```

### Step 4: Verify the Deployment

```bash
kubectl get pods -l app=postgresql-customer
kubectl get svc postgres-cust
```

Test connectivity from within the cluster:

```bash
kubectl run pg-test --rm -it --restart=Never --image=registry.redhat.io/rhel9/postgresql-15 -- \
  psql -h postgres-cust -U customer -d fantaco_customer -c "SELECT 1"
```

## Connection Details

The application should connect to PostgreSQL using these values:

| Variable      | Value              |
|---------------|--------------------|
| Host          | `postgres-cust`    |
| Port          | `5432`             |
| Database      | `fantaco_customer` |
| Username      | `customer`         |
| Password      | `customer`         |
| Admin Password| `postgres`         |

The JDBC URL for a Quarkus application would be:

```
jdbc:postgresql://postgres-cust:5432/fantaco_customer
```

## Applying All at Once

To deploy everything in one command:

```bash
kubectl apply -f deployment/kubernetes/postgres/
```

## Cleanup

Remove all PostgreSQL resources:

```bash
kubectl delete -f deployment/kubernetes/postgres/
```

Or by label:

```bash
kubectl delete all -l app=postgresql-customer
kubectl delete svc postgres-cust
```

## Troubleshooting

| Symptom | Check |
|---------|-------|
| Pod not starting | `kubectl describe pod -l app=postgresql-customer` -- check image pull errors |
| CrashLoopBackOff | `kubectl logs -l app=postgresql-customer` -- check env variable issues |
| Service not reachable | `kubectl get endpoints postgres-cust` -- ensure endpoints are populated |
| Image pull error | Verify `registry.redhat.io` credentials or switch to `docker.io/library/postgres:15` |

## Notes

- The deployment uses `emptyDir` for storage, meaning data is **not persistent** across pod restarts. For production, replace with a `PersistentVolumeClaim`.
- The image `registry.redhat.io/rhel9/postgresql-15` requires Red Hat registry authentication. If unavailable, substitute with `docker.io/library/postgres:15` and adjust env vars (`POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`).
