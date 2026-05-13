#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${1:-customer-api}"
DB_SERVICE="customerdb"

echo "=== Tearing down $APP_NAME from OpenShift ==="
echo "Project: $(oc project -q)"
echo ""

read -rp "This will delete ALL resources for '$APP_NAME' and '$DB_SERVICE'. Continue? [y/N] " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

echo "Removing application resources..."
oc delete all -l app="$APP_NAME" --ignore-not-found

echo "Removing database resources..."
oc delete all -l app="$DB_SERVICE" --ignore-not-found
oc delete pvc -l app="$DB_SERVICE" --ignore-not-found

echo ""
echo "=== Teardown complete ==="
