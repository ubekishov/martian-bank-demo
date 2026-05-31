#!/usr/bin/env bash
# Copyright (c) 2023 Cisco Systems, Inc. and its affiliates All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [--docker|--native]

Creates .env files from .env.example for each microservice (skips existing .env).

  --docker   Docker Compose mode (default): Mongo at mongo:27017 with root:example
  --native   Native Mac mode: local MongoDB at localhost:27017

Run without flags to choose interactively.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --docker) MODE="docker"; shift ;;
    --native) MODE="native"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$MODE" ]]; then
  echo "Select local development mode:"
  echo "  1) docker  — Docker Compose (recommended)"
  echo "  2) native  — run services on host (Mac: scripts/run_local.sh)"
  read -r -p "Choice [1]: " choice
  case "${choice:-1}" in
    1|docker|Docker) MODE="docker" ;;
    2|native|Native) MODE="native" ;;
    *) echo "Invalid choice." >&2; exit 1 ;;
  esac
fi

SERVICES=(
  customer-auth
  atm-locator
  dashboard
  accounts
  transactions
  loan
  ui
)

copy_env() {
  local service="$1"
  local dir="$ROOT/$service"
  local example="$dir/.env.example"
  local target="$dir/.env"

  if [[ ! -f "$example" ]]; then
    echo "  skip $service (no .env.example)"
    return
  fi

  if [[ -f "$target" ]]; then
    echo "  keep $service/.env (already exists)"
    return
  fi

  cp "$example" "$target"
  echo "  created $service/.env"
}

apply_mode() {
  local service="$1"
  local target="$ROOT/$service/.env"

  [[ -f "$target" ]] || return

  if [[ "$MODE" == "docker" ]]; then
    return
  fi

  case "$service" in
    customer-auth|atm-locator)
      {
        echo ""
        echo "# Applied by setup_local.sh --native"
        echo "DATABASE_HOST=localhost"
      } >> "$target"
      sed -i.bak '/^DB_URL=/d' "$target" && rm -f "$target.bak"
      ;;
    dashboard)
      sed -i.bak \
        -e 's|^DB_URL=.*|DB_URL=mongodb://localhost:27017|' \
        -e 's|^ACCOUNT_HOST=.*|ACCOUNT_HOST=localhost|' \
        -e 's|^TRANSACTION_HOST=.*|TRANSACTION_HOST=localhost|' \
        -e 's|^LOAN_HOST=.*|LOAN_HOST=localhost|' \
        -e 's|^CUSTOMER_AUTH_HOST=.*|CUSTOMER_AUTH_HOST=localhost|' \
        -e 's|^ATM_LOCATOR_HOST=.*|ATM_LOCATOR_HOST=localhost|' \
        "$target" && rm -f "$target.bak"
      ;;
    accounts|transactions|loan)
      sed -i.bak 's|^DB_URL=.*|DB_URL=mongodb://localhost:27017|' "$target" && rm -f "$target.bak"
      ;;
  esac
}

echo "Martian Bank local setup (mode: $MODE)"
echo "Creating .env files from .env.example ..."
for svc in "${SERVICES[@]}"; do
  copy_env "$svc"
done

echo "Applying $MODE settings ..."
for svc in "${SERVICES[@]}"; do
  apply_mode "$svc"
done

echo ""
if [[ "$MODE" == "docker" ]]; then
  cat <<EOF
Next steps (Docker Compose):
  ./scripts/start_docker.sh
  # or:
  docker compose up --build

App URLs:
  UI (direct):     http://localhost:3000
  UI (via nginx):  http://localhost:8080
  Auth API:        http://localhost:8000/api/users/
  Dashboard:       http://localhost:5000/
EOF
else
  cat <<EOF
Next steps (native Mac):
  1. Start MongoDB locally (https://www.mongodb.com/docs/manual/installation/)
  2. Run all services:
       cd scripts && bash run_local.sh
  3. Open http://localhost:3000

To stop native services:
       cd scripts && bash stop_local.sh
EOF
fi
