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

GC_PATH="/opt/genesis_core"
IMG_ARTS_PATH="/opt/gci_base/genesis/images/genesis_base"
WORK_DIR="/var/lib/genesis"
SYSTEMD_SERVICE_DIR=/etc/systemd/system/

PASSWD="${GEN_USER_PASSWD:-ubuntu}"
DEV_MODE=$([ -d "$GC_PATH" ] && echo "true" || echo "false")

# Install packages
sudo apt update

# We only need the package `libvirt-dev` since Genesis Core is not divided
# into multiple packages. It's not a big problem so far. About 7Mb addtional
# space and some time to install.
sudo apt install -y build-essential python3.12-dev python3.12-venv \
    cloud-guest-utils irqbalance qemu-guest-agent libev-dev \
    libvirt-dev 

# Install the Core Agent
# Prepare a fresh virtrual environment
rm -fr "$GC_PATH/.venv"
mkdir -p "$GC_PATH/.venv"
python3 -m venv "$GC_PATH/.venv"
source "$GC_PATH"/.venv/bin/activate
pip install pip --upgrade

# In the dev mode the genesis_core package is installed from the local machine
if [[ "$DEV_MODE" == "true" ]]; then
    pip install -r "$GC_PATH"/requirements.txt
    pip install -e "$GC_PATH"
# Install the Core Agent as a package from pypi
else
    pip install genesis-core
fi

sudo cp -r "$IMG_ARTS_PATH/genesis_core_agent" /etc/
sudo ln -sf "$GC_PATH/.venv/bin/gc-agent" "/usr/bin/gc-agent"


# Install stuff for bootstrap procedure and systemd services
sudo mkdir -p "$WORK_DIR/bootstrap/scripts/"
sudo cp "$IMG_ARTS_PATH/bootstrap.sh" "$WORK_DIR/bootstrap/"
sudo cp "$IMG_ARTS_PATH/root_autoresize.sh" "/usr/bin/"
sudo cp "$IMG_ARTS_PATH/genesis-bootstrap.service" $SYSTEMD_SERVICE_DIR
sudo cp "$IMG_ARTS_PATH/genesis-root-autoresize.service" $SYSTEMD_SERVICE_DIR
sudo cp "$IMG_ARTS_PATH/gc-agent.service" $SYSTEMD_SERVICE_DIR

# Enable genesis core services
sudo systemctl enable genesis-bootstrap genesis-root-autoresize gc-agent

# Set default password
cat > /tmp/__passwd <<EOF
ubuntu:$PASSWD
EOF

sudo chpasswd < /tmp/__passwd
rm -f /tmp/__passwd

# Cleanup
sudo rm -fr /opt/gci_base