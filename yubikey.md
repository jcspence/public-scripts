# Yubikey

## Configuring SSH auth with Yubikey 

<https://github.com/drduh/YubiKey-Guide>

[on Fedora]

```bash
# Install software
sudo dnf install -y gnupg2 pinentry-curses pcsc-lite pcsc-lite-libs gnupg2-smime

cat << eof > ~/.gnupg/gpg-agent.conf
enable-ssh-support
pinentry-program /usr/bin/pinentry-curses
default-cache-ttl 60
max-cache-ttl 120
eof

# Restart gpg-agent, maybe unplug and reconnect yubikey.
gpg-connect-agent /bye

echo 'export GPG_TTY="$(tty)"
export SSH_AUTH_SOCK="/run/user/$UID/gnupg/S.gpg-agent.ssh"
gpg-connect-agent updatestartuptty /bye' >> ~/.bashrc 

. ~/.bashrc 
```

Misc

	ssh-add -L | grep cardno:000 > ~/.ssh/yubikey.pub
