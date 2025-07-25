#!/bin/bash

dimlightcol() {
	color="${1#"#"}"

	if [[ -n $2 ]]; then factor=$2; else factor=0.8; fi
	
	for i in {0..4..2}; do
		hex=${color:$i:2}
		dec=$((16#$hex))
		dim=$(printf "%.0f" $(echo "$dec * $factor" | bc))
		dim_color+=$(printf "%02x" $dim)
	done
	
	printf "#$dim_color"
}

# Set wallpaper based on time of day and generate colorscheme
TIME=$(date +"%-H")
DATE=$(date +"%d-%m-%Y")

if [[ -f "$HOME/.config/prayerhistory/$DATE.txt" ]]; then
	PRAYER_NAME=$(bash $HOME/.config/hypr/scripts/prayer.sh -n)
	case $PRAYER_NAME in
		"Fajr") FOLDER="dawn";;
		"Sunrise") FOLDER="morning";;
		"Dhuhr") FOLDER="noon";;
		"Asr") FOLDER="afternoon";;
		"Maghrib") FOLDER="sunset";;
		"Isha" | "Midnight" | "Last Third") FOLDER="night";;
	esac
else
	if [[ $TIME -ge 4 && $TIME -lt 7 ]]; then
		FOLDER="dawn"
	elif [[ $TIME -ge 7 && $TIME -lt 11 ]]; then
		FOLDER="morning"
	elif [[ $TIME -ge 11 && $TIME -lt 15 ]]; then
		FOLDER="noon"
	elif [[ $TIME -ge 15 && $TIME -lt 18 ]]; then
		FOLDER="afternoon"
	elif [[ $TIME -ge 18 && $TIME -lt 20 ]]; then
		FOLDER="sunset"
	elif [[ $TIME -ge 20 ]] || [[ $TIME -lt 4 ]]; then
		FOLDER="night"
	fi
fi

if [ "$1" == "-c" ]; then
	THEME="element-icon { size: 115px; margin: 0 12px; }\
		listview { columns: 4; lines: 3; }\
		element { padding: 0; color: transparent; }\
		mainbox { children: [listview]; }\
		window { height: 600px; }"

	WALLPAPER=$(ls $HOME/.config/wallpapers/$FOLDER/ | while read A; do echo -en "$A\x00icon\x1f$HOME/.config/wallpapers/$FOLDER/$A\n"; done | rofi -dmenu -p " Wallpaper" -theme-str "$THEME")
	if [ -z "$WALLPAPER" ]; then exit; fi
else
	WALLPAPER=$(ls -1 $HOME/.config/wallpapers/$FOLDER/ | sort --random-sort | head -1)
fi

WALLPAPER="$HOME/.config/wallpapers/$FOLDER/$WALLPAPER"
wal -si $WALLPAPER
hyprctl hyprpaper preload $WALLPAPER && hyprctl hyprpaper wallpaper ,$WALLPAPER

# Waybar, rofi, and dunst colors
cp $HOME/.config/waybar/style.bak $HOME/.config/waybar/style.css
cp $HOME/.config/rofi/theme.bak $HOME/.config/rofi/theme.rasi
cp $HOME/.config/dunst/dunstrc.bak $HOME/.config/dunst/dunstrc

FG=$(cat $HOME/.cache/wal/colors.json | jq -r .special.foreground)
BG=$(cat $HOME/.cache/wal/colors.json | jq -r .special.background)
LIGHTBG=$(dimlightcol $BG 2.0)
LIGHTERBG=$(dimlightcol $BG 2.5)

# If color is dark then set text to FG for good readability, otherwise set text to BG
check_brightness() {
	local color=$1
	local threshold=100

	local r=$((16#${color:1:2}))
	local g=$((16#${color:3:2}))
	local b=$((16#${color:5:2}))

	# Calculate perceived brightness using YIQ formula
	local brightness=$(( (r * 299 + g * 587 + b * 114) / 1000 ))

	if [ $brightness -lt $threshold ]; then echo "$FG"; else echo "$BG"; fi
}

colors=("1" "2" "4" "5")
color_names=("FG" "BG" "LIGHTBG" "LIGHTERBG" "DIMMERCOL2")

for color in "${colors[@]}"; do
	fg_color_name="FGCOL${color}"
	color_name="COL${color}"
	dim_color_name="DIM${color_name}"

	color_names+=("$fg_color_name")
	color_names+=("$color_name")
	color_names+=("$dim_color_name")

	eval "$color_name=$(jq -r .colors.color${color} $HOME/.cache/wal/colors.json)"
	eval "$dim_color_name=\$(dimlightcol \$$color_name)"
	eval "$fg_color_name=\$(check_brightness \$$color_name)"
done

DIMMERCOL2=$(dimlightcol $COL2 0.55)

# color_names=("FG" "BG" "LIGHTBG" "LIGHTERBG" "FGCOL1" "FGCOL2" "FGCOL4" "FGCOL5" "COL1" "COL2" "COL4" "COL5" "DIMCOL1" "DIMCOL2" "DIMMERCOL2" "DIMCOL4" "DIMCOL5")
configs=("waybar/style.css" "rofi/theme.rasi" "dunst/dunstrc")

for config in "${configs[@]}"; do
	for color in "${color_names[@]}"; do
		sed -i "s/__${color}__/${!color}/" "$HOME/.config/$config"
	done
done

# Restart waybar
killall waybar
waybar &

# Kill dunst
killall dunst
