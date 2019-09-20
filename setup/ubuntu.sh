#!/usr/bin/env sh
set -e -v

# setup/ubuntu.sh
# Performs some setup for new systems (ubuntu).

sudo apt-get update
sudo apt-get install -y \
	bash \
	build-essential \
	git \
	linux-headers-$(uname -r) \
	openssh-server \
	vim \
	virtualbox-guest-dkms \
	zsh

# TODO configure sshd

./setup/general-user-noninteractive.sh

# === Begin Interactive ===
./setup/general-user-interactive.sh

# Update?
sudo apt-get update
# May need to reboot and install more linux headers.
