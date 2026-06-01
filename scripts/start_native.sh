#!/usr/bin/env bash
# Copyright (c) 2023 Cisco Systems, Inc. and its affiliates All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs"
PID_DIR="$ROOT/.pids"
DASHBOARD_PORT="${DASHBOARD_PORT:-5002}"

mkdir -p "$LOG_DIR" "$PID_DIR"

ensure_mongo() {
  if mongosh --eval "db.runCommand({ ping: 1 })" --quiet >/dev/null 2>&1; then
    echo "MongoDB is running."
    return
  fi

  echo "Starting MongoDB ..."
  brew services start mongodb/brew/mongodb-community@8.0 >/dev/null 2>&1 || true

  for _ in $(seq 1 15); do
    if mongosh --eval "db.runCommand({ ping: 1 })" --quiet >/dev/null 2>&1; then
      echo "MongoDB is running."
      return
    fi
    sleep 1
  done

  echo "brew services failed; starting mongod directly ..."
  mkdir -p /opt/homebrew/var/mongodb /opt/homebrew/var/log/mongodb 2>/dev/null || true
  mongod --dbpath /opt/homebrew/var/mongodb \
    --logpath /opt/homebrew/var/log/mongodb/mongo.log \
    --fork >/dev/null 2>&1 || true

  for _ in $(seq 1 15); do
    if mongosh --eval "db.runCommand({ ping: 1 })" --quiet >/dev/null 2>&1; then
      echo "MongoDB is running."
      return
    fi
    sleep 1
  done

  echo "MongoDB is not reachable. Install and start it:" >&2
  echo "  brew install mongodb/brew/mongodb-community@8.0" >&2
  echo "  mongod --dbpath /opt/homebrew/var/mongodb --logpath /opt/homebrew/var/log/mongodb/mongo.log --fork" >&2
  exit 1
}

write_native_env() {
  cat > "$ROOT/customer-auth/.env" <<EOF
PORT=8000
JWT_SECRET=martian-bank-dev-secret-change-me
DATABASE_HOST=localhost
EOF

  cat > "$ROOT/atm-locator/.env" <<EOF
PORT=8001
DATABASE_HOST=localhost
EOF

  cat > "$ROOT/dashboard/.env" <<EOF
DB_URL=mongodb://localhost:27017
SERVICE_PROTOCOL=http
ACCOUNT_HOST=localhost
TRANSACTION_HOST=localhost
LOAN_HOST=localhost
CUSTOMER_AUTH_HOST=localhost
ATM_LOCATOR_HOST=localhost
PORT=$DASHBOARD_PORT
EOF

  for svc in accounts transactions loan; do
    cat > "$ROOT/$svc/.env" <<EOF
DB_URL=mongodb://localhost:27017
SERVICE_PROTOCOL=http
EOF
  done

  cat > "$ROOT/ui/.env" <<EOF
VITE_ACCOUNTS_URL=http://127.0.0.1:$DASHBOARD_PORT/account/
VITE_TRANSFER_URL=http://127.0.0.1:$DASHBOARD_PORT/transaction/
VITE_LOAN_URL=http://127.0.0.1:$DASHBOARD_PORT/loan/
EOF
}

start_node_service() {
  local name="$1"
  local dir="$ROOT/$1"
  local script="$2"
  local pid_file="$PID_DIR/$name.pid"

  if [[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
    echo "$name already running (pid $(cat "$pid_file"))."
    return
  fi

  echo "Starting $name ..."
  (
    cd "$dir"
    npm install --silent
    if [[ "$script" == "auth" || "$script" == "atm" ]]; then
      npx nodemon server.js
    else
      npm run "$script"
    fi
  ) >>"$LOG_DIR/$name.log" 2>&1 &
  echo $! >"$pid_file"
}

start_python_service() {
  local name="$1"
  local module="$2"
  local dir="$ROOT/$name"
  local pid_file="$PID_DIR/$name.pid"

  if [[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
    echo "$name already running (pid $(cat "$pid_file"))."
    return
  fi

  echo "Starting $name ..."
  (
    cd "$dir"
    rm -rf venv_bankapp
    python3 -m venv venv_bankapp
    # shellcheck disable=SC1091
    source venv_bankapp/bin/activate
    pip install -r requirements.txt -q
    python3 "$module.py"
  ) >>"$LOG_DIR/$name.log" 2>&1 &
  echo $! >"$pid_file"
}

wait_for_port() {
  local port="$1"
  local label="$2"
  for _ in $(seq 1 60); do
    if lsof -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
      echo "$label is listening on :$port"
      return 0
    fi
    sleep 1
  done
  echo "$label failed to start on :$port. See logs/$label.log" >&2
  return 1
}

echo "Martian Bank — native startup"
write_native_env
ensure_mongo

start_python_service accounts accounts
start_python_service transactions transaction
start_python_service loan loan
start_python_service dashboard dashboard
start_node_service customer-auth auth
start_node_service atm-locator atm
start_node_service ui ui

wait_for_port 50051 "accounts"
wait_for_port 50052 "transactions"
wait_for_port 50053 "loan"
wait_for_port "$DASHBOARD_PORT" "dashboard"
wait_for_port 8000 "customer-auth"
wait_for_port 3000 "ui"

cat <<EOF

Martian Bank is running:
  UI:         http://localhost:3000
  Dashboard:  http://127.0.0.1:$DASHBOARD_PORT
  Auth API:   http://localhost:8000/api/users/

Logs: $LOG_DIR/
Stop: $ROOT/scripts/stop_native.sh
EOF
