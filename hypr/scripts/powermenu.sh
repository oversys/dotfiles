#!/bin/bash

ACTION=$(printf "⏻\n\n󰤄\n\n" | rofi -dmenu -mesg "<span font='16' rise='-2000'>󰜹</span> Uptime: $(uptime -p | sed -e 's/up //g')" -config ~/.config/rofi/powermenu.rasi)

case "$ACTION" in
	"⏻") shutdown now;;
	"") reboot;;
	"󰤄") systemctl suspend;;
	"") hyprlock;;
	"") hyprctl dispatch exit;;
esac
