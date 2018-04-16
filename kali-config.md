
I'm attending a CTF this evening, so I took a few minutes to clean up and publish my usual Kali configuration procedure.

## Configure Remote Access

    # Disable password auth, set AllowUsers for sshd.
    # If I had more time, I'd apply my hardened config with Ansible.
    sudo vim /etc/ssh/sshd_config

    # Set sshd to run.
    sudo systemctl enable ssh
    sudo systemctl start ssh 

    # Set SSH authorized_keys file. 


## Install Software

<http://byteschef.com/kali-linux-install-on-virtualbox-with-guest-additions/>  
<https://www.blackmoreops.com/2014/06/10/correct-way-install-virtualbox-guest-additions-packages-kali-linux/>
 

    # Update bbqsql.
    # The touch at the end tells my configuration scripts that bbqsql has been installed.
    sudo dnf install -y python-pip &&
    sudo pip install gevent requests &&
    mkdir -p ~/src &&
    cd ~/src &&
    git clone https://github.com/Neohapsis/bbqsql.git &&
    cd bbqsql &&
    { sudo python setup.py clean;
      sudo python setup.py install; } &&
    sudo touch /etc/ansible-bbqsql-update-v0

    # Upgrade Kali.
    sudo apt-get update && sudo apt-get dist-upgrade

    # I'm just assuming that I should reboot after a dist-upgrade.
    #sudo reboot

    # May want to also update software. 
    sudo apt-get update && 
     sudo apt-get upgrade -y 

    # It may be necessary to enable another apt source by uncommenting 
    # a line in /etc/apt/sources.list .
    # http://docs.kali.org/general-use/kali-linux-sources-list-repositories
    sudo vim /etc/apt/sources.list

    # Check that Linux headers are installed.
    sudo apt-get install -y linux-headers-$(uname -r)

    # I use VirtualBox, so I want to install VirtualBox Guest Additions.
    # Mount guest additions, then
    cp /media/cdrom/VBoxLinuxAdditions.run ~/
    chmod 755 ~/VBoxLinuxAdditions.run
    sudo ~/VBoxLinuxAdditions.run

    # Now, reboot again.
    #sudo reboot

## Configure Software


    # Configure git. 

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
    
    eof

    # Replace Name and Email with actual name and email address. 
    git config --add --global user.name "Name"
    git config --add --global user.email "Email"


