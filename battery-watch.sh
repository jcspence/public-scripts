#!/bin/bash

# Written by Carey Spence.

# This script will post repeated notifications to Slack or Discord if
#  the computer's battery gets low.
# Written for use with the i3 window manager.
# Just run from i3 config with:
#  exec bash /path/to/this/file

# TODO Clean up stdout.

[ -x ~/.config/battery-watch ] &&
	. ~/.config/battery-watch

function discord () {
	username="$HOSTNAME"
	# If you would like this script to post to Discord, put
	#  an appropriate webhook url in 'slack_url', after appending
	#  /slack to the url.
	# https://support.discordapp.com/hc/en-us/articles/228383668-Intro-to-Webhooks
	# Slack may be supported - just set slack_url and dest.
	# https://api.slack.com/incoming-webhooks
	slack_url="$BATTERY_WATCH_WEBHOOK"
	dest="$BATTERY_WATCH_DEST"
	msg="$1"

	[ -n "$slack_url" ] &&
		curl \
			-X POST \
			--data-urlencode \
			'payload={"channel": "'"$dest"'", "username": "'"$username"'", "text": "'"$msg"'", "icon_emoji": ":comet:"}' \
			"$slack_url"
}

function complain () {
	i3-nagbar --message "$*" &
	complainpid=$!
}

function ensure_nagbar_down () {
	ps "$complainpid" && kill "$complainpid"
	# Mark that no nagbar is active.
	complainpid=1000000
}

function battery-check () {
	cat /sys/class/power_supply/BAT?/capacity
}

# Initialize variables
complainpid=1000000
bat=0
ac=5

# Main loop.
while sleep "${BATTERY_WATCH_DELAY:-15}"; do
	
	# Preserve last status
	oldac="$ac";
	oldbat="$bat"

	# Get data
	read ac < /sys/class/power_supply/AC/online;
	bat="$(battery-check)"

	# Notify on AC power change.
	if [ "$ac" -ne "$oldac" ]; then
		if [ "$ac" == 1 ]; then
			discord ":electric_plug: $HOSTNAME is connected to AC power."
		else
			discord ":battery: $HOSTNAME is running on batteries at ${bat}%."
		fi
	fi

	if [ "$ac" == 0 ] && [ "$bat" -lt 20 ]; then
	# Running on batteries and battery is low.
		# If there's no nagbar yet
		if ! ps $complainpid >/dev/null; then
			# Make nagbar
			complain "Low battery! $bat%"
			# Post caution
			discord ":warning: ${HOSTNAME}: Low battery! $bat%" &
		elif [ "$bat" -ne "$oldbat" ]; then
			# Battery level has changed.
			# Update nagbar.
			ensure_nagbar_down
			complain "Low battery! $bat%"
			# Update discord.
			discord ":warning: ${HOSTNAME}: Low battery! $bat%" &
		fi

	elif [ "$bat" -eq 100 ] && [ "$oldbat" -ne 100 ]; then
	# Battery is now fully charged
	discord ":white_check_mark: ${HOSTNAME}: Battery charged! $bat%"

	elif [ "$complainpid" -ne 1000000 ]; then
	# There is a nagbar open, but the system is running on AC power or the battery is not low.
	# If the battery jumps from <20 to 100, this will not fire until the second loop.
	# (In that case, the user may just manually kill the nagbar.)
		ensure_nagbar_down
	fi;

done
