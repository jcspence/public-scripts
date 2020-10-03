#!/usr/bin/env -S bash -e -u -o pipefail 

# Based on code at https://www.zerotier.com/download/

keyring=/tmp/zerotier-install-keyring-dd5ad24d-932c-4935-92af-195bf1751814

# TODO verify fingerprint

curl -s https://raw.githubusercontent.com/zerotier/ZeroTierOne/master/doc/contact%40zerotier.com.gpg |
	gpg \
		--quiet \
		--no-default-keyring \
		--keyring "$keyring" \
		--import

install=$(
	curl -s https://install.zerotier.com/ |
	gpgv \
		--enable-special-filenames \
		--output - \
		--keyring "$keyring")

bash <<< "$install"
