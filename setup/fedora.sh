#!/usr/bin/env sh
set -e -v

# setup/fedora.sh
# Performs some setup for new systems (fedora).

# TODO install build essential equivalent

sudo dnf install -y \
	cmake \
	ctags \
	curl \
	dtrx \
	git \
	gnupg \
	magic-wormhole \
	make \
	ncdu \
	openssh-server \
	pandoc \
	pv \
	python3 \
	python3-devel \
	python3-pip \
	tmux \
	vim \
	virtualbox-guest-additions \
	wget \
	xclip \
	zsh

sudo dnf install -y \
	"https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"

./setup/zerotier.sh

./setup/general-user-noninteractive.sh

# === Begin Interactive ===
./setup/general-user-interactive.sh

# Update?
sudo dnf upgrade #-y
# May need to reboot and install more linux headers.
