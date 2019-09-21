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

# Enable service to start at boot.
sudo systemctl enable ssh
# Ensure service is started/restarted to load new configuration.
sudo systemctl restart ssh

