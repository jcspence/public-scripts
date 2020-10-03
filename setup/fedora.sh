#!/usr/bin/env sh
set -e -v

# setup/fedora.sh
# Performs some setup for new systems (fedora).

# TODO install build essential equivalent

sudo dnf instll -y \
	cmake \
	ctags \
	curl \
	dtrx \
	git \
	gnupg \
	linux-headers-$(uname -r) \
	magic-wormhole \
	make \
	mosh \
	ncdu \
	openssh-server \
	pandoc \
	pv \
	python3 \
	python3-dev \
	python3-pip \
	tmux \
	vim \
	virtualbox-guest-dkms \
	wget \
	xclip \
	zsh

./setup/general-user-noninteractive.sh

# === Begin Interactive ===
./setup/general-user-interactive.sh

# Update?
sudo dnf upgrade #-y
# May need to reboot and install more linux headers.
