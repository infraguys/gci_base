#!/usr/bin/env bash

# Copyright 2025 Genesis Corporation
#
# All Rights Reserved.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

set -eu
set -x
set -o pipefail

SDK_PATH="/opt/gcl_sdk"
IMG_ARTS_PATH="/opt/gci_base/genesis/images/genesis_base"
WORK_DIR="/var/lib/genesis"
SYSTEMD_SERVICE_DIR=/etc/systemd/system/

# Observability and monitoring tools
PROMTAIL_VERSION="3.4.4"
PROMTAIL_BUILD_DIR="/tmp/promtail"

PASSWD="${GEN_USER_PASSWD:-ubuntu}"
DEV_MODE=$([ -d "$SDK_PATH" ] && echo "true" || echo "false")

# Metrics and logs
ALLOY_VERSION="1.10.0"

# Install packages
apt update && apt dist-upgrade -y


apt install -y build-essential python3.12-dev python3.12-venv \
    cloud-guest-utils irqbalance qemu-guest-agent libev-dev 

# Install the Core Agent
# Prepare a fresh virtrual environment
rm -fr "$SDK_PATH/.venv"
mkdir -p "$SDK_PATH/.venv"
python3 -m venv "$SDK_PATH/.venv"
source "$SDK_PATH"/.venv/bin/activate
pip install pip --upgrade

# In the dev mode the genesis_core package is installed from the local machine
if [[ "$DEV_MODE" == "true" ]]; then
    pip install -r "$SDK_PATH"/requirements.txt
    pip install -e "$SDK_PATH"
# Install the Core Agent as a package from pypi
else
    pip install gcl-sdk
fi

cp -r "$IMG_ARTS_PATH/etc/genesis_universal_agent" /etc/
ln -sf "$SDK_PATH/.venv/bin/genesis-universal-agent" "/usr/bin/genesis-universal-agent"


# Install stuff for bootstrap procedure and systemd services
mkdir -p "$WORK_DIR/bootstrap/scripts/"
cp "$IMG_ARTS_PATH/bootstrap.sh" "$WORK_DIR/bootstrap/"
cp "$IMG_ARTS_PATH/root_autoresize.sh" "/usr/bin/"
cp "$IMG_ARTS_PATH/etc/systemd/genesis-bootstrap.service" $SYSTEMD_SERVICE_DIR
cp "$IMG_ARTS_PATH/etc/systemd/genesis-root-autoresize.service" $SYSTEMD_SERVICE_DIR
cp "$IMG_ARTS_PATH/etc/systemd/genesis-universal-agent.service" $SYSTEMD_SERVICE_DIR

# Enable genesis core services
systemctl enable genesis-bootstrap genesis-root-autoresize genesis-universal-agent

# Install Observability Agents
mkdir -p "$PROMTAIL_BUILD_DIR"
cd "$PROMTAIL_BUILD_DIR"

wget -q "https://github.com/grafana/loki/releases/download/v${PROMTAIL_VERSION}/promtail_${PROMTAIL_VERSION}_amd64.deb"
dpkg -i "promtail_${PROMTAIL_VERSION}_amd64.deb"
usermod -aG adm promtail

systemctl enable promtail.service

# Install Alloy
wget -q https://github.com/grafana/alloy/releases/download/v${ALLOY_VERSION}/alloy-${ALLOY_VERSION}-1.amd64.deb
sudo dpkg -i alloy-${ALLOY_VERSION}-1.amd64.deb
rm -f alloy-${ALLOY_VERSION}-1.amd64.deb

# Set default password
cat > /tmp/__passwd <<EOF
ubuntu:$PASSWD
EOF

chpasswd < /tmp/__passwd
rm -f /tmp/__passwd

# Cleanup
rm -fr /opt/gci_base
rm -rf "$PROMTAIL_BUILD_DIR"
