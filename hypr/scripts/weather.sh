#!/bin/bash

ROUND_TEMP=1
ROUND_WIND=1

# Automatically detect location
while [[ -z "$LOC" ]]; do
	LOC=$(curl -s https://ipinfo.io | jq -r '.loc')
done

LAT=$(echo $LOC | awk -F ',' '{print $1}')
LON=$(echo $LOC | awk -F ',' '{print $2}')

# Get weather info: weather code, temperature, wind direction and speed
while [[ -z "$weather_info" ]]; do
	weather_info=$(curl -s "https://api.open-meteo.com/v1/forecast?latitude=$LAT&longitude=$LON&current=temperature_2m,apparent_temperature,wind_speed_10m,wind_direction_10m,weather_code&forecast_days=1")
done

TIME_OF_DAY=$(bash $HOME/.config/hypr/scripts/prayer.sh -n)

if [[ "$TIME_OF_DAY" == "Maghrib" || "$TIME_OF_DAY" == "Isha" ]]; then
	TIME_OF_DAY="Night"
else
	TIME_OF_DAY="Day"
fi

# Function to map weather code to a Nerd Font icon
# Reference: https://gist.github.com/stellasphere/9490c195ed2b53c707087c8c2db4ec0c
weather_icon() {
	case $1 in
		0) [[ $TIME_OF_DAY == "Night" ]] && echo "󰖔" || echo "󰖨" ;; # sunny/clear
		1 | 2) [[ $TIME_OF_DAY == "Night" ]] && echo "" || echo "" ;; # partly sunny/cloudy
		3) echo "󰅟" ;; # cloudy
		61 | 63 | 65 | 51 | 53 | 55 | 80 | 81 | 82) echo "" ;; # light/normal/heavy rain/drizzle/showers
		95 | 96 | 99) echo "" ;; # thunderstorm
		71 | 73 | 75 | 85 | 86) echo "󰼶" ;; # light/normal/heavy snow or light/normal snow showers
		66 | 67 | 56 | 57) echo "" ;; # light/normal freezing rain/drizzle
		45 | 48) echo "󰖑" ;; # fog
		66 | 67 | 56 | 57) echo "" ;; # light/normal freezing rain/drizzle
		*) echo "$1" ;;
	esac
}

# Function to map wind direction to an arrow character
wind_icon() {
	local deg=$1

	if (( deg >= 0 && deg < 23 )) || (( deg >= 338 && deg <= 360 )); then
		# echo ""  # N
		echo ""
	elif (( deg >= 23 && deg < 68 )); then
		# echo ""  # NE
		echo "↙"
	elif (( deg >= 68 && deg < 113 )); then
		# echo ""  # E
		echo ""
	elif (( deg >= 113 && deg < 158 )); then
		# echo ""  # SE
		echo "↖"
	elif (( deg >= 158 && deg < 203 )); then
		# echo ""  # S
		echo ""
	elif (( deg >= 203 && deg < 248 )); then
		# echo ""  # SW
		echo "↗"
	elif (( deg >= 248 && deg < 293 )); then
		# echo ""  # W
		echo ""
	elif (( deg >= 293 && deg < 338 )); then
		# echo ""  # NW
		echo "↘"
	fi
}

## Parse fields

# Units
temp_unit=$(echo "$weather_info" | jq -r '.current_units.temperature_2m')
wind_speed_unit=$(echo "$weather_info" | jq -r '.current_units.wind_speed_10m')
wind_dir_unit=$(echo "$weather_info" | jq -r '.current_units.wind_direction_10m')

# Temperature
weather_code=$(echo "$weather_info" | jq -r '.current.weather_code')
temp=$(echo "$weather_info" | jq -r '.current.temperature_2m')
real_feel=$(echo "$weather_info" | jq -r '.current.apparent_temperature')

temp_icon=$(printf "%s%s%s" "<span font='18' rise='-3000'>" $(weather_icon "$weather_code") "</span>")

if [[ "$ROUND_TEMP" -eq 1 ]]; then
	temp=$(printf "%.0f" "$temp")
	real_feel=$(printf "%.0f" "$real_feel")
fi

# Wind
wind_speed=$(echo "$weather_info" | jq -r '.current.wind_speed_10m')
wind_dir=$(echo "$weather_info" | jq -r '.current.wind_direction_10m')
wind_dir_icon=$(printf "%s%s%s" "<span font='16' rise='-3000'>" $(wind_icon "$wind_dir") "</span>")

if [[ "$ROUND_WIND" -eq 1 ]]; then
	wind_speed=$(printf "%.0f" "$wind_speed")
fi

## Print module json
printf "{\"text\": \"$temp_icon $temp$temp_unit\", \"alt\": \"$temp_icon $temp$temp_unit ($real_feel$temp_unit)\", \"tooltip\": \"$wind_dir_icon $wind_speed $wind_speed_unit @ $wind_dir$wind_dir_unit\" }\n"

