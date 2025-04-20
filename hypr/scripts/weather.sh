#!/bin/bash

# Automatically detect location
LOCATION=$(curl -s https://ipinfo.io)
COUNTRY="$(echo $LOCATION | jq -r '.country')"
CITY="$(echo $LOCATION | jq -r '.city')"

# Get weather info: icon, temperature, wind direction/speed
weather_info=$(curl -s "wttr.in/$CITY?format=%c%t%20(%f)%20%w")

# Example output: "☀️  +18°C (+18°C) ↘10km/h"

# Function to map weather emoji to Nerd Font icons
icon_map() {
  case "$1" in
    "☀️") echo "󰖙" ;;  # sunny
    "🌤") echo "󰖕" ;;  # partly sunny
    "⛅") echo "󰖖" ;;  # partly cloudy
    "☁️") echo "󰖐" ;;  # cloudy
    "🌧") echo "󰖖" ;;  # rain
    "⛈") echo "󰖓" ;;  # thunderstorm
    "🌩") echo "󰖓" ;;  # thunder
    "🌨") echo "󰼶" ;;  # snow
    "❄️") echo "󰼶" ;;  # snow alt
    "🌫") echo "󰖑" ;;  # fog
    *) echo "$1" ;;
  esac
}

# Parse fields
icon=$(echo "$weather_info" | awk '{print $1}')
temp=$(echo "$weather_info" | awk '{print $2}' | sed "s/+//")
real_feel=$(echo "$weather_info" | awk '{print $3}' | sed "s/+//")

wind_info=$(echo "$weather_info" | awk '{print $4}')
wind_dir="${wind_info:0:1}"
wind_speed="${wind_info:1}"

# Convert emoji icon to Nerd Font icon
nf_icon=$(printf "%s%s%s" "<span font='16' rise='-2000'>" $(icon_map "$icon") "</span>")

printf "{\"text\": \"$nf_icon $temp\", \"alt\": \"$nf_icon $temp $real_feel\", \"tooltip\": \"$wind_dir $wind_speed\" }\n"

