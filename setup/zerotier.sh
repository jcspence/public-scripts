#!/usr/bin/env -S bash -e -u -o pipefail 

# Based on code at https://www.zerotier.com/download/

firstring=/tmp/zerotier-install-keyring-f2128c78-e379-4d60-ac9b-8eeeca8a716a
trustedring=/tmp/zerotier-install-trusted-keyring-f2128c78-e379-4d60-ac9b-8eeeca8a716a
fpr=74A5E9C458E1A431F1DA57A71657198823E52A61

curl -s https://raw.githubusercontent.com/zerotier/ZeroTierOne/master/doc/contact%40zerotier.com.gpg |
	gpg \
		--quiet \
		--no-default-keyring \
		--keyring "$firstring" \
		--import

gpg \
	--quiet \
	--no-default-keyring \
	--keyring "$firstring" \
	--export "$fpr" |
	gpg \
		--quiet \
		--no-default-keyring \
		--keyring "$trustedring" \
		--import

install=$(
	curl -s https://install.zerotier.com/ |
	gpgv \
		--enable-special-filenames \
		--output - \
		--keyring "$trustedring")

bash <<< "$install"
