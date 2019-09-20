#!/usr/bin/env sh
set -e -v

# User-specific config - may interact with user.

grep name ~/.gitconfig > /dev/null || {
	echo -n "[git config] Name: "
	read name
	git config --add --global user.name "$name"
}
grep email ~/.gitconfig > /dev/null || {
	echo -n "[git config] Email: "
	read email
	git config --add --global user.email "$email"
}
