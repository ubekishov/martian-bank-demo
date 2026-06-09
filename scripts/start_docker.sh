#!/usr/bin/env bash
# Copyright (c) 2023 Cisco Systems, Inc. and its affiliates All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Setting up Docker Compose environment files ..."
"$ROOT/scripts/setup_local.sh" --docker

echo ""
echo "Starting Martian Bank with Docker Compose ..."
cd "$ROOT"
docker compose up --build "$@"
