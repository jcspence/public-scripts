#!/usr/bin/env sh
set -e -v

# Assumes done elsewhere:
# - install sshd
# - configure authorized_keys

# Also does not:
# - open port

# Disable password auth.
sudo sed -i \
    /etc/ssh/sshd_config \
    -e 's/[ #]*PasswordAuthentication.*/PasswordAuthentication no/'

# Verify
sudo grep '^PasswordAuthentication no$' /etc/ssh/sshd_config >/dev/null

# Enable and start.
sudo systemctl enable ssh
sudo systemctl start ssh

