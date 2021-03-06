#!/usr/bin/env sh
set -v -e

# User specific config - should not interact with user.

# TODO possibly add config dir

pip3 install --user pyyaml pipenv

# Template git config.
[ -e ~/.gitconfig ] || 
cat << eof >> ~/.gitconfig
# This is Git's per-user configuration file.
[push]
	default = matching
[alias]
    # some adapted from http://gitolite.com/tips-1.html
    
    s       = status -s -b
    stat    = status -s -b
    
    ci  = commit -v
    co  = checkout

    d   = diff -C
    dc  = diff -C --cached
eof

# Configure vim.
[ -e ~/.vimrc ] || 
cat << eof >> ~/.vimrc
set tabstop=4
set autoindent
set expandtab
" no automatic visual mode.
set mouse-=a
eof

# Add ssh authorized keys.
[ -e ~/.ssh/authorized_keys ] || {
  mkdir -p ~/.ssh &&
  curl -Ss -o ~/.ssh/authorized_keys https://ecbf.us/carey.keys &&
  chmod go= -R ~/.ssh
}

# Create a private key.
ls ~/.ssh/id_* > /dev/null 2>&1 || {
  ssh-keygen \
	-t ed25519 \
	-f ~/.ssh/id_ed25519 \
	-C "$USER@$HOSTNAME $(date +%Y-%m-%d)" \
	-N ''
}

# TODO install YouCompleteMe
