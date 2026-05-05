#!/usr/bin/env bash

# Copyright 2025-2026 Genesis Corporation
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

AGENT_PATH="/opt/universal_agent"
IMG_ARTS_PATH="/opt/gci_base/genesis/images/exordos_base"
WORK_DIR="/var/lib/exordos"
SYSTEMD_SERVICE_DIR=/etc/systemd/system/

PASSWD="${GEN_USER_PASSWD:-ubuntu}"
SDK_PATH="/opt/gcl_sdk"
DEV_MODE=$([ -d "$SDK_PATH" ] && echo "true" || echo "false")

# Metrics and logs
ALLOY_VERSION="1.10.0"

if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
    sudo mv /etc/apt/sources.list.d/ubuntu.sources /etc/apt/sources.list.d/ubuntu.sources.bak
fi
if [ -f /etc/apt/sources.list ]; then
    sudo mv /etc/apt/sources.list /etc/apt/sources.list.bak
fi
sudo cp "$IMG_ARTS_PATH/etc/apt/sources.list" /etc/apt/sources.list

# Install packages
sudo apt update
sudo apt dist-upgrade -y
sudo apt install -y build-essential python3.12-dev python3.12-venv \
    cloud-guest-utils irqbalance qemu-guest-agent libev-dev rsync parted j2cli

export UV_INSTALLER_GHE_BASE_URL=https://github.com
export UV_INSTALL_DIR="/usr/local/bin"
curl -LsSf https://github.com/astral-sh/uv/releases/download/0.11.7/uv-installer.sh | sh
uv self version

# Install the Core Agent
# Prepare a fresh virtual environment
rm -fr "$AGENT_PATH/.venv"
mkdir -p "$AGENT_PATH/.venv"
python3 -m venv "$AGENT_PATH/.venv"
source "$AGENT_PATH"/.venv/bin/activate
pip install pip --upgrade

# In the dev mode the genesis_core package is installed from the local machine
if [[ "$DEV_MODE" == "true" ]]; then
    pip install -r "$SDK_PATH"/requirements.txt
    pip install -e "$SDK_PATH"
# Install the Core Agent as a package from pypi
else
    pip install gcl-sdk=="$GEN_SDK_VERSION"
fi

sudo cp -r "$IMG_ARTS_PATH/etc/genesis_universal_agent" /etc/
sudo ln -sf "$AGENT_PATH/.venv/bin/genesis-universal-agent" "/usr/bin/genesis-universal-agent"


# Install stuff for bootstrap procedure and systemd services
sudo mkdir -p "$WORK_DIR/bootstrap/scripts/"
sudo cp "$IMG_ARTS_PATH/bootstrap.sh" "$WORK_DIR/bootstrap/"
sudo cp "$IMG_ARTS_PATH/root_autoresize.sh" "/usr/bin/"
sudo cp "$IMG_ARTS_PATH/etc/systemd/exordos-bootstrap.service" $SYSTEMD_SERVICE_DIR
sudo cp "$IMG_ARTS_PATH/etc/systemd/exordos-root-autoresize.service" $SYSTEMD_SERVICE_DIR
sudo cp "$IMG_ARTS_PATH/etc/systemd/genesis-universal-agent.service" $SYSTEMD_SERVICE_DIR
sudo mkdir "/usr/local/lib/exordos/"
sudo cp -a "$IMG_ARTS_PATH/lib/." "/usr/local/lib/exordos/"

# Enable exordos core services
sudo systemctl enable exordos-bootstrap exordos-root-autoresize genesis-universal-agent

# Install Alloy
wget -q https://repository.genesis-core.tech/alloy/alloy-${ALLOY_VERSION}-1.amd64.deb
#wget -q https://github.com/grafana/alloy/releases/download/v${ALLOY_VERSION}/alloy-${ALLOY_VERSION}-1.amd64.deb
sudo dpkg -i alloy-${ALLOY_VERSION}-1.amd64.deb
rm -f alloy-${ALLOY_VERSION}-1.amd64.deb

# Set default password
cat > /tmp/__passwd <<EOF
ubuntu:$PASSWD
EOF

sudo chpasswd < /tmp/__passwd
rm -f /tmp/__passwd

# Cleanup
# remove old kernels, headers and modules, keep only the latest one
LATEST_KERNEL_PKG=$(dpkg-query -W -f='${db:Status-Abbrev} ${Package}\n' 'linux-image-[0-9]*' 2>/dev/null | grep '^ii' | awk '{print $2}' | sort -V | tail -n 1 || true)
if [ -n "$LATEST_KERNEL_PKG" ]; then
    VERSION=$(echo "$LATEST_KERNEL_PKG" | sed 's/linux-image-//' | sed 's/-generic$//')
    OLD_PKGS=$(dpkg-query -W -f='${db:Status-Abbrev} ${Package}\n' 'linux-image-[0-9]*' 'linux-headers-[0-9]*' 'linux-modules-[0-9]*' 'linux-modules-extra-[0-9]*' 2>/dev/null | grep '^ii' | awk '{print $2}' | grep -v "$VERSION" || true)
    if [ -n "$OLD_PKGS" ]; then
        sudo DEBIAN_FRONTEND=noninteractive apt-get autopurge -y $OLD_PKGS
    fi
fi
sudo apt autopurge -y snapd libllvm19
sudo rm -fr /opt/gci_base
sudo apt-get clean
sudo rm -rf /var/lib/apt/lists/*
sudo rm -rf /tmp/*
fstrim -v /
