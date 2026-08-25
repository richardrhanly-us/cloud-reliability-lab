#!/bin/bash

set -euo pipefail

REPO_URL="https://github.com/richardrhanly-us/cloud-reliability-lab.git"
APP_DIR="/opt/cloud-reliability-lab"
APP_USER="cloudlab"
APP_GROUP="cloudlab"

echo "=== Cloud Reliability Lab AWS bootstrap starting ==="

# ------------------------------------------------------------
# 1. Update operating system packages
# ------------------------------------------------------------

dnf update -y

# ------------------------------------------------------------
# 2. Install required software
# ------------------------------------------------------------

dnf install -y \
    git \
    nginx \
    python3.11 \
    python3.11-pip \
    amazon-cloudwatch-agent

# ------------------------------------------------------------
# 3. Create dedicated application user
# ------------------------------------------------------------

if ! id "${APP_USER}" >/dev/null 2>&1; then
    useradd \
        --system \
        --create-home \
        --shell /sbin/nologin \
        "${APP_USER}"
fi

# ------------------------------------------------------------
# 4. Deploy application repository
# ------------------------------------------------------------

if [ ! -d "${APP_DIR}/.git" ]; then
    git clone "${REPO_URL}" "${APP_DIR}"
else
    git -C "${APP_DIR}" fetch origin
    git -C "${APP_DIR}" reset --hard origin/main
fi

chown -R "${APP_USER}:${APP_GROUP}" "${APP_DIR}"

# ------------------------------------------------------------
# 5. Create Python virtual environment
# ------------------------------------------------------------

if [ ! -d "${APP_DIR}/.venv" ]; then
    sudo -u "${APP_USER}" python3.11 -m venv "${APP_DIR}/.venv"
fi

sudo -u "${APP_USER}" \
    "${APP_DIR}/.venv/bin/python" -m pip install --upgrade pip

sudo -u "${APP_USER}" \
    "${APP_DIR}/.venv/bin/python" -m pip install \
    -r "${APP_DIR}/requirements.txt"

# ------------------------------------------------------------
# 6. Create application log directory
# ------------------------------------------------------------

mkdir -p /var/log/cloud-reliability-lab
chown "${APP_USER}:${APP_GROUP}" /var/log/cloud-reliability-lab

# ------------------------------------------------------------
# 7. Install systemd service
# ------------------------------------------------------------

cp \
    "${APP_DIR}/systemd/cloud-reliability-lab-aws.service" \
    /etc/systemd/system/cloud-reliability-lab.service

systemctl daemon-reload
systemctl enable cloud-reliability-lab

# ------------------------------------------------------------
# 8. Configure nginx
# ------------------------------------------------------------

if [ ! -f /etc/nginx/nginx.conf.original ]; then
    cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.original
fi

python3 - <<'PY'
from pathlib import Path

path = Path("/etc/nginx/nginx.conf")
text = path.read_text()

old = """    server {
        listen       80;
        listen       [::]:80;
        server_name  _;
        root         /usr/share/nginx/html;

        # Load configuration files for the default server block.
        include /etc/nginx/default.d/*.conf;

        error_page 404 /404.html;
        location = /404.html {
        }

        error_page 500 502 503 504 /50x.html;
        location = /50x.html {
        }
    }
"""

if old in text:
    path.write_text(text.replace(old, "", 1))
PY

cp \
    "${APP_DIR}/nginx/cloud-reliability-lab.conf" \
    /etc/nginx/conf.d/cloud-reliability-lab.conf

nginx -t

systemctl enable nginx

# ------------------------------------------------------------
# 9. Configure CloudWatch Agent
# ------------------------------------------------------------

cp \
    "${APP_DIR}/cloudwatch/amazon-cloudwatch-agent.json" \
    /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
    -s

# ------------------------------------------------------------
# 10. Start application and nginx
# ------------------------------------------------------------

systemctl restart cloud-reliability-lab
systemctl restart nginx

# ------------------------------------------------------------
# 11. Validate deployment
# ------------------------------------------------------------

for attempt in {1..10}; do
    if curl --fail --silent http://127.0.0.1:8000/health >/dev/null; then
        break
    fi

    if [ "${attempt}" -eq 10 ]; then
        echo "FastAPI health check failed after 10 attempts."
        exit 1
    fi

    sleep 2
done

curl --fail http://127.0.0.1:8000/health
curl --fail http://127.0.0.1/health

echo
echo "=== Cloud Reliability Lab AWS bootstrap completed successfully ==="