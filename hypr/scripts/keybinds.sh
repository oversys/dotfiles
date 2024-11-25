#!/bin/bash

# Path to Hyprland configuration file
hyprland_conf="$HOME/.config/hypr/hyprland.conf"

# Extract the value of $mainMod using awk
mainMod=$(awk '/^\$mainMod =/ {print $3}' "$hyprland_conf")

keybinds=()
while read -r description_line && read -r keybind_line; do
	# Extract the description (removing '#@ ')
	description="${description_line#'#@ '}"

	# Extract the bind components
	bind="${keybind_line#'bind = '}"
	IFS=',' read -r modifiers key action command <<<"$bind"

	# Add '+' between modifiers, replace $mainMod with its actual value
	modifiers=$(echo "$modifiers" | sed 's/ / + /g' | sed "s/\$mainMod/$mainMod/")

	# Remove newline from key
	key=$(echo "$key" | tr -d ' \n')

	# Format the keybind
	keybinds+=("$modifiers + $key::$description")
done < <(grep -A1 --no-group-separator '^#@' "$hyprland_conf")

# Calculate the maximum keybind length
max_keybind_length=0
for entry in "${keybinds[@]}"; do
	keybind="${entry%%::*}"
	if ((${#keybind} > max_keybind_length)); then
		max_keybind_length=${#keybind}
	fi
done

# Format the keybinds with right-aligned descriptions
formatted_keybinds=()
for entry in "${keybinds[@]}"; do
	# Separate keybind and description
	keybind="${entry%%::*}"
	description="${entry##*::}"

	# Minimum of 4 dots for padding
	dot_count=$((max_keybind_length - ${#keybind} + 4))
	dots=$(printf '%*s' "$dot_count" '' | tr ' ' '.')

	formatted_keybinds+=("${keybind} ${dots} ${description}")
done

# Display the rofi menu
printf '%s\n' "${formatted_keybinds[@]}" | rofi -dmenu -i -p "󰌌 Keybinds"

