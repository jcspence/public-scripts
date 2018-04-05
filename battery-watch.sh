#!/bin/bash

# Written by Carey Spence. 

# This script will post repeated notifications to Slack or Discord if 
#  the computer's battery gets low.
# Written for use with the i3 window manager.
# Just run from i3 config with:
#  exec bash /path/to/this/file

# TODO Clean up stdout.

function discord () { 
    username="$HOSTNAME"
    # If you would like this script to post to Discord, put 
    #  an appropriate webhook url in 'slack_url', after appending
    #  /slack to the url.
    # https://support.discordapp.com/hc/en-us/articles/228383668-Intro-to-Webhooks
    # Slack may be supported - just set slack_url and dest.
    # https://api.slack.com/incoming-webhooks
    slack_url=''
    dest=''
    msg="$*"

    [ -n "$slack_url" ] && curl -X POST --data-urlencode 'payload={"channel": "'"$dest"'", "username": "'"$username"'", "text": "'"$msg"'", "icon_emoji": ":comet:"}'  "$slack_url"
}

function complain () { 
    i3-nagbar --message "$*" & 
    complainpid=$!
}

function battery-check () {
    cat /sys/class/power_supply/BAT?/capacity
}


complainpid=1000000
bat=0; ac=5;

# Main loop.
while sleep 15; do 
    
    # Watch power source.

    oldac="$ac";
    read ac < /sys/class/power_supply/AC/online;

    # If change then notify.
    if [ "$ac" -ne "$oldac" ]; then
        if [ "$ac" == 1 ]; then
            discord ":electric_plug: $HOSTNAME has been connected to AC power."
        else
            discord ":battery: $HOSTNAME is running on batteries."
        fi
    fi

    # Watch battery.

    oldbat="$bat"
    bat="$(battery-check)"

    if [ "$ac" == 0 ] && [ "$bat" -lt 20 ]; then 
        # Running on batteries and battery is low.
        discord ":warning: ${HOSTNAME}: Low battery! $bat%" &
        # Only make nagbar if needed.
        ps $complainpid >/dev/null || complain "Low battery! $bat%"
        # Refresh if new level.
        [ "$bat" -ne "$oldbat" ] && { kill "$complainpid"; complain "Low battery! $bat%"; }

    elif [ "$bat" -eq 100 ] && [ "$oldbat" -ne 100 ]; then 
        # Charged
        discord ":white_check_mark: ${HOSTNAME}: Battery charged! $bat%"

    else 
        # If the battery jumps from <20 to 100, this will not fire.
        # In that case, the user may just manually kill the nagbar.
        # Kill nagbar if up
        ps "$complainpid" && kill "$complainpid"
    fi;

done
