#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${1:-customer-api}"
GIT_REPO="${2:-}"
DB_SERVICE="customerdb"
DB_USER="customerdb_user"
DB_PASS="customerdb_pass"
DB_NAME="customerdb"

if [ -z "$GIT_REPO" ]; then
  echo "Usage: $0 <app-name> <git-repo-url> [branch]"
  echo ""
  echo "Example:"
  echo "  $0 customer-api https://github.com/org/repo.git main"
  exit 1
fi

BRANCH="${3:-}"
GIT_REF="$GIT_REPO"
if [ -n "$BRANCH" ]; then
  GIT_REF="${GIT_REPO}#${BRANCH}"
fi

echo "=== Deploying $APP_NAME to OpenShift ==="
echo "Git source: $GIT_REF"
echo "Project:    $(oc project -q)"
echo ""

# --- PostgreSQL ---
echo "--- Step 1: PostgreSQL ---"
if oc get dc/"$DB_SERVICE" &>/dev/null; then
  echo "PostgreSQL deployment '$DB_SERVICE' already exists, skipping."
else
  oc new-app --template=postgresql-persistent \
    -p POSTGRESQL_USER="$DB_USER" \
    -p POSTGRESQL_PASSWORD="$DB_PASS" \
    -p POSTGRESQL_DATABASE="$DB_NAME" \
    -p VOLUME_CAPACITY=1Gi \
    -p DATABASE_SERVICE_NAME="$DB_SERVICE"
  echo "Waiting for PostgreSQL to be ready..."
  oc rollout status dc/"$DB_SERVICE" --timeout=120s
fi
echo ""

# --- Application ---
echo "--- Step 2: Application (S2I build) ---"
if oc get bc/"$APP_NAME" &>/dev/null; then
  echo "Build config '$APP_NAME' already exists. Triggering rebuild..."
  oc start-build "$APP_NAME" --follow
else
  oc new-app \
    registry.access.redhat.com/ubi8/openjdk-17~"$GIT_REF" \
    --name="$APP_NAME" \
    --build-env=MAVEN_ARGS="package -DskipTests" \
    -e DB_HOST="$DB_SERVICE" \
    -e DB_PORT=5432 \
    -e DB_NAME="$DB_NAME" \
    -e DB_USER="$DB_USER" \
    -e DB_PASSWORD="$DB_PASS"
  echo "Following build logs..."
  oc logs -f bc/"$APP_NAME"
fi

echo "Waiting for application rollout..."
oc rollout status deployment/"$APP_NAME" --timeout=300s
echo ""

# --- Route ---
echo "--- Step 3: Route ---"
if oc get route "$APP_NAME" &>/dev/null; then
  echo "Route already exists."
else
  oc expose svc/"$APP_NAME"
fi

APP_URL=$(oc get route "$APP_NAME" -o jsonpath='{.spec.host}')
echo ""
echo "=== Deployment Complete ==="
echo "Application URL: http://$APP_URL"
echo "Health check:    http://$APP_URL/q/health"
echo "API base:        http://$APP_URL/api/v1/customers"
