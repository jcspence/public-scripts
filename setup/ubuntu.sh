#!/usr/bin/env sh
set -e -v

# setup/ubuntu.sh
# Performs some setup for new systems (ubuntu).

sudo apt-get update
sudo apt-get install -y \
	linux-headers-$(uname -r)

# TODO install(/ensure) git, vim, bash, zsh
# TODO install build-essential 

# TODO install vbox guest additions

# TODO configure sshd

./setup/general-user-noninteractive.sh

# === Begin Interactive ===
./setup/general-user-interactive.sh

# Update?
sudo apt-get update
# May need to reboot and install more linux headers.
