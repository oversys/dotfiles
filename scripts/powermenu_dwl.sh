#!/bin/bash

if [[ "$1" == "-l" ]]; then
	ACTION=""
else
	ACTION=$(printf "⏻\n\n󰤄\n\n" | rofi -dmenu -mesg "<span font='16' rise='-2000'>󰜹</span> Uptime: $(uptime -p | sed -e 's/up //g')" -config ~/.config/rofi/powermenu.rasi)
fi

case "$ACTION" in
	"⏻") shutdown now;;
	"") reboot;;
	"󰤄") systemctl suspend;;
	"") [ ! -f /tmp/lock.png ] && ffmpeg -y -i $(jq -r '.wallpaper' $HOME/.cache/wal/colors.json) -vf 'gblur=sigma=60:steps=6' /tmp/lock.png; gtklock -s $HOME/.config/gtklock/style.css -x $HOME/.config/gtklock/layout.xml --background /tmp/lock.png;;
	"") pkill dwl;;
esac

