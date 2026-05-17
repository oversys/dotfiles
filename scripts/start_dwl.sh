#!/bin/bash

# Everything has to be in this block otherwise dwl startup is slow
{
	# Uncomment for screen sharing/recording. Required packages: xdg-desktop-portal and xdg-desktop-portal-wlr
	# /usr/lib/xdg-desktop-portal &
	# /usr/lib/xdg-desktop-portal-wlr &

	# One time setup for xdg-desktop-portal
	# mkdir -p $HOME/.config/xdg-desktop-portal
	# printf '[preferred]\norg.freedesktop.impl.portal.ScreenCast=wlr\norg.freedesktop.impl.portal.Screenshot=wlr' $HOME/.config/xdg-desktop-portal/portals.conf

	# One time setup for xdg-desktop-portal-wlr
	# mkdir -p $HOME/.config/xdg-desktop-portal-wlr
	# printf '[screencast]\nchooser_type = dmenu\nchooser_cmd = rofi -dmenu -p "Select output"' $HOME/.config/xdg-desktop-portal-wlr/config

	$HOME/.config/scripts/wallpaper_dwl.sh &
	$HOME/.config/scripts/batbluemon.sh &
} &

exit 0

