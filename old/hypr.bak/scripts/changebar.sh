#!/bin/bash

cd $HOME/.config/waybar

if [[ -f "config2.jsonc" ]]; then
	mv config.jsonc config1.jsonc
	mv style.bak style1.bak

	mv config2.jsonc config.jsonc
	mv style2.bak style.bak

	mv $HOME/.config/hypr/scripts/wallpaper.sh $HOME/.config/hypr/scripts/wallpaper1.sh
	mv $HOME/.config/hypr/scripts/wallpaper2.sh $HOME/.config/hypr/scripts/wallpaper.sh

	sed -i "s/# layerrule = blur, waybar/layerrule = blur, waybar/" $HOME/.config/hypr/hyprland.conf
else
	mv config.jsonc config2.jsonc
	mv style.bak style2.bak

	mv config1.jsonc config.jsonc
	mv style1.bak style.bak

	mv $HOME/.config/hypr/scripts/wallpaper.sh $HOME/.config/hypr/scripts/wallpaper2.sh
	mv $HOME/.config/hypr/scripts/wallpaper1.sh $HOME/.config/hypr/scripts/wallpaper.sh

	sed -i "s/layerrule = blur, waybar/# layerrule = blur, waybar/" $HOME/.config/hypr/hyprland.conf
fi
