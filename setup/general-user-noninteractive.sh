#!/usr/bin/env sh -e
set -v

# User specific config - should not interact with user.

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

