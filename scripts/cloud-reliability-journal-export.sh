#!/bin/bash
set -euo pipefail

LOG_DIR="/var/log/cloud-reliability-lab"
LOG_FILE="${LOG_DIR}/systemd.log"

mkdir -p "${LOG_DIR}"
touch "${LOG_FILE}"

journalctl \
  -u cloud-reliability-lab \
  -f \
  -n 0 \
  -o short-iso \
  >> "${LOG_FILE}"