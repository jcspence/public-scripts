#!/usr/bin/env sh
set -e -v

# setup/ubuntu.sh
# Performs some setup for new systems (ubuntu).

sudo apt update
sudo apt install -y \
	apparmor-utils \
	bash \
	build-essential \
	cmake \
	ctags \
	curl \
	dtrx \
	git \
	gnupg \
	linux-headers-$(uname -r) \
	make \
	mosh \
	ncdu \
	openssh-server \
	pandoc \
	pv \
	python \
	python-dev \
	python-pip \
	python3 \
	python3-dev \
	python3-pip \
	tmux \
	vim \
	virtualbox-guest-dkms \
	wget \
	xclip \
	zsh

# TODO configure sshd

./setup/general-user-noninteractive.sh

# === Begin Interactive ===
./setup/general-user-interactive.sh

# Update?
sudo apt upgrade
# May need to reboot and install more linux headers.
