# Discord notification 
# (for battery-watch.sh)

[ -x ~/.config/battery-watch ] &&
       . ~/.config/battery-watch

function discord-notify () {
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
