#!/bin/bash

# Mawaqit.net masjid ID (gets prayer times directly from the masjid rather than from aladhan.com)
MASJID_ID="__MASJID_ID__"

# Set to 1 to enable caching of mawaqit.net calendar
USE_CACHE=1

## LOCATION - If country or city are not entered then location will be fetched automatically

# Country name or ISO 3166 code (ex: The Netherlands, Netherlands, NL, or NLD)
COUNTRY="__COUNTRY__"

# City name (ex: Makkah)
CITY="__CITY__"

# 3 - Muslim World League
# 4 - Umm Al-Qura University, Makkah
# 8 - Gulf Region
# 16 - Dubai (unofficial)
# DEFAULT: 3 - Muslim World League
METHOD="__METHOD__"

# Dates & Times
CURRENT_DATE=$(date +"%d-%m-%Y")
CURRENT_TIME=$(date +"%H:%M")
YESTERDAY_DATE=$(date -d "yesterday" +"%d-%m-%Y")

# Files & Directories
PRAYER_DIR="$HOME/.config/prayerhistory"
PRAYER_FILE="$PRAYER_DIR/$CURRENT_DATE.txt"
CACHE_FILE="$PRAYER_DIR/${MASJID_ID}.json"
NOTIFIED_FILE="$PRAYER_DIR/notified"
HIJRI_FILE="$PRAYER_DIR/hijri.txt"

# Include source of prayer times at the top of the prayer times file
SOURCE_COMMENT=""

if [[ ! -f "$PRAYER_FILE" ]]; then
	if [[ "$MASJID_ID" != "__MASJID_ID__" && -n "$MASJID_ID" ]]; then
		if [[ $USE_CACHE -eq 1 && -f "$CACHE_FILE" ]]; then
			SOURCE_COMMENT="# Fetched prayer times from mawaqit.net with masjid ID: \"$MASJID_ID\" (local cache)"
		else
			SOURCE_COMMENT="# Fetched prayer times from mawaqit.net with masjid ID: \"$MASJID_ID\""
		fi
	elif [[ "$COUNTRY" != "__COUNTRY__" && -n "$COUNTRY" && "$CITY" != "__CITY__" && -n "$CITY" ]]; then
		SOURCE_COMMENT="# Fetched prayer times from api.aladhan.com with given location: $CITY, $COUNTRY"
	else
		# Automatically detect location if neither masjid ID nor location are provided
		LOCATION=$(curl -s https://ipinfo.io)
		COUNTRY="$(echo $LOCATION | jq -r '.country')"
		CITY="$(echo $LOCATION | jq -r '.city')"

		SOURCE_COMMENT="# Fetched prayer times from api.aladhan.com with automatically detected location: $CITY, $COUNTRY"
	fi
fi

# Default method
if [[ "$METHOD" == "__METHOD__" || -z "$METHOD" ]]; then METHOD=3; fi

# Helper Functions

to_arabic_num() {
	read western_arabic
	echo $western_arabic | sed 'y/0123456789/٠١٢٣٤٥٦٧٨٩/'
}

arabic_prayer_name() {
	local PRAYER_ARABIC

	case "$1" in
		"Fajr") PRAYER_ARABIC="الفجر";;
		"Sunrise") PRAYER_ARABIC="الشروق";;
		"Dhuhr") PRAYER_ARABIC="الظهر";;
		"Asr") PRAYER_ARABIC="العصر";;
		"Maghrib") PRAYER_ARABIC="المغرب";;
		"Isha") PRAYER_ARABIC="العشاء";;
		"Midnight") PRAYER_ARABIC="منتصف الليل";;
		"Last Third") PRAYER_ARABIC="الثلث الأخير";;
	esac

	echo "$PRAYER_ARABIC"
}

to_mins() {
	IFS=: read -r hour minute <<< "$1"
	echo $((10#$hour * 60 + 10#$minute))
}

duration() {
	local start_minutes=$(to_mins "$1")
	local end_minutes=$(to_mins "$2")
	local diff_minutes=$((end_minutes - start_minutes))

	# Handle cases where end time is on the next day
	if ((diff_minutes < 0)); then
		diff_minutes=$((diff_minutes + 1440)) # Add 24 hours in minutes
	fi

	local hours=$((diff_minutes / 60))
	local minutes=$((diff_minutes % 60))

	if [[ "$3" == "ar" ]]; then
		local minutes_text

		if ((hours == 0)); then
			case $minutes in
				1) minutes_text="دقيقة واحدة";;
				2) minutes_text="دقيقتان";;
				3|4|5|6|7|8|9|10) minutes_text="دقائق";;
				*) minutes_text="دقيقة";;
			esac

			if ((minutes <= 2)); then
				printf "$minutes_text"
			else
				printf "$(echo $minutes | to_arabic_num) $minutes_text"
			fi
		else
			printf '%02d:%02d\n' "$hours" "$minutes" | to_arabic_num
		fi
	else
		if ((hours == 0)); then
			if ((minutes == 1)); then
				printf "%d min" "$minutes"
			else
				printf "%d mins" "$minutes"
			fi
		else
			printf '%02d:%02d\n' "$hours" "$minutes"
		fi
	fi
}

# Fetch data from mawaqit.net
fetch_mawaqit() {
	local response=$(curl -s "https://mawaqit.net/en/$MASJID_ID")

	if [ $? -eq 0 ]; then
		local conf_data=$(echo "$response" | grep -oP 'var confData = \K.*(?=;)')

		if [ -n "$conf_data" ]; then
			echo "$conf_data"
		else
			echo "Failed to extract confData JSON for $MASJID_ID" >&2
		fi
	else
		echo "Failed to fetch data for $MASJID_ID" >&2
	fi
}

get_timings() {
	if [[ "$MASJID_ID" == "__MASJID_ID__" || -z "$MASJID_ID" ]]; then
		# Fetch times from api.aladhan.com
		local TIMES=$(curl -Ls "http://api.aladhan.com/v1/timingsByCity?country=$COUNTRY&city=$CITY&method=$METHOD" | jq -r '[.data.timings.Fajr, .data.timings.Sunrise, .data.timings.Dhuhr, .data.timings.Asr, .data.timings.Maghrib, .data.timings.Isha]')
	else
		# Fetch times from mawaqit.net
		local DAY=$(echo "$CURRENT_DATE" | awk -F'-' '{print $1 + 0}')
		local MONTH=$(echo "$CURRENT_DATE" | awk -F'-' '{print $2 - 1}')

		if [[ $USE_CACHE -eq 1 && -f "$CACHE_FILE" ]]; then
			# Use cached calendar
			local TIMES=$(jq -r ".calendar[$MONTH][\"$DAY\"]" "$CACHE_FILE")
		else
			local RESPONSE=$(fetch_mawaqit "$MASJID_ID")
			if [[ $USE_CACHE -eq 1 ]]; then echo "$RESPONSE" > "$CACHE_FILE"; fi

			local TIMES=$(echo "$RESPONSE" | jq -r ".calendar[$MONTH][\"$DAY\"]")
		fi
	fi

	# Get Fajr time in minutes
	local FAJR_TIME=$(echo "$TIMES" | jq -r '.[0]')
	local FAJR_MINUTES=$(to_mins "$FAJR_TIME")

	# Get Maghrib time in minutes
	local MAGHRIB_TIME=$(echo "$TIMES" | jq -r '.[4]')
	local MAGHRIB_MINUTES=$(to_mins "$MAGHRIB_TIME")

	# Get total minutes from Maghrib to Fajr
	local TOTAL_MINUTES=$(((FAJR_MINUTES + 1440) - MAGHRIB_MINUTES))

	# Calculate midnight time
	local MIDNIGHT_MINUTES=$((FAJR_MINUTES - (TOTAL_MINUTES / 2)))

	if [ $MIDNIGHT_MINUTES -lt 0 ]; then
		MIDNIGHT_MINUTES=$((MIDNIGHT_MINUTES + 1440))
	fi

	local MIDNIGHT_TIME=$(printf "%02d:%02d" $((MIDNIGHT_MINUTES / 60)) $((MIDNIGHT_MINUTES % 60)))

	# Calculate last third time
	local LAST_THIRD_MINUTES=$((FAJR_MINUTES - (TOTAL_MINUTES / 3)))

	if [ $LAST_THIRD_MINUTES -lt 0 ]; then
		LAST_THIRD_MINUTES=$((LAST_THIRD_MINUTES + 1440))
	fi

	local LAST_THIRD_TIME=$(printf "%02d:%02d" $((LAST_THIRD_MINUTES / 60)) $((LAST_THIRD_MINUTES % 60)))

	echo "$TIMES" | jq -r \
		--arg midnight "$MIDNIGHT_TIME" \
		--arg last_third "$LAST_THIRD_TIME" \
		'{
			Fajr: .[0],
			Sunrise: .[1],
			Dhuhr: .[2],
			Asr: .[3],
			Maghrib: .[4],
			Isha: .[5],
			Midnight: $midnight,
			"Last Third": $last_third
		} | to_entries | map("\(.key): \(.value)") | .[]'
}

get_hijri() {
	# Using aladhan.com
	#
	# today=$(curl -Ls "https://api.aladhan.com/v1/gToH/$CURRENT_DATE" | jq .data.hijri)
	# day=$(echo $today | jq -r .day)
	# month=$(echo $today | jq -r .month.en)
	# year=$(echo $today | jq -r .year)
	#
	# printf "$(date +%a), $day $month $year"

	# -------------------

	# Using datehijri.com

	# if [[ ! -f "$HIJRI_FILE" ]]; then touch "$HIJRI_FILE"; fi

	# read -r LAST_DATE LAST_HIJRI < "$HIJRI_FILE"

	# if [ "$LAST_DATE" != "$CURRENT_DATE" ]; then
	# 	local converter=$(curl -s https://datehijri.com/ajax.php | jq -r .converter)
	# 	local date=$(echo $converter | jq -r ".result.hijri.[1]" | to_arabic_num)
	# 	local today="$(echo $converter | jq -r .day)، $date"

	# 	if [ -n "$converter" ]; then echo "$CURRENT_DATE $today" > "$HIJRI_FILE"; fi
	# else
	# 	local today=$LAST_HIJRI
	# fi

	# echo "$today"

	# -------------

	# Using JavaScript

	if [[ ! -f "$HIJRI_FILE" ]]; then touch "$HIJRI_FILE"; fi

	read -r LAST_DATE LAST_HIJRI < "$HIJRI_FILE"

	if [ "$LAST_DATE" != "$CURRENT_DATE" ]; then
		local hijri_date=$(node -e "console.log(new Date().toLocaleDateString('ar-SA-u-ca-islamic', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' }))" | sed "s/ هـ//")

		if [ -n "$hijri_date" ]; then echo "$CURRENT_DATE $hijri_date" > "$HIJRI_FILE"; fi
	else
		local hijri_date=$LAST_HIJRI
	fi

	echo "$hijri_date"
}

CURRENT_MINUTES=$(to_mins "$CURRENT_TIME")

if [[ ! -f "$PRAYER_FILE" ]]; then
	TIMINGS=$(get_timings)

	if [ -n "$TIMINGS" ]; then
		echo "$SOURCE_COMMENT" > "$PRAYER_FILE"
		echo "$TIMINGS" >> "$PRAYER_FILE"
	fi
fi

FAJR_TIME=$(awk -F: '/Fajr/ {gsub(/[",]/, "", $0); gsub(/^[ \t]+/, "", $2); print $2 ":" $3}' "$PRAYER_FILE")
FAJR_MINUTES=$(to_mins "$FAJR_TIME")

if [[ $CURRENT_MINUTES -lt $FAJR_MINUTES ]]; then
	CURRENT_DATE=$YESTERDAY_DATE
	PRAYER_FILE="$PRAYER_DIR/$CURRENT_DATE.txt"

	if [[ ! -f "$PRAYER_FILE" ]]; then
		TIMINGS=$(get_timings)

		if [ -n "$TIMINGS" ]; then echo "$TIMINGS" > "$PRAYER_FILE"; fi
	fi

	MIDNIGHT_TIME=$(awk -F: '/Midnight/ {gsub(/[",]/, "", $0); gsub(/^[ \t]+/, "", $2); print $2 ":" $3}' "$PRAYER_FILE")
	MIDNIGHT_MINUTES=$(to_mins "$MIDNIGHT_TIME")

	LAST_THIRD_TIME=$(awk -F: '/Last Third/ {gsub(/[",]/, "", $0); gsub(/^[ \t]+/, "", $2); print $2 ":" $3}' "$PRAYER_FILE")
	LAST_THIRD_MINUTES=$(to_mins "$LAST_THIRD_TIME")

	if [[ $MIDNIGHT_MINUTES -gt $LAST_THIRD_MINUTES && "$MIDNIGHT_TIME" != "$CURRENT_TIME" ]]; then MIDNIGHT_MINUTES=$((MIDNIGHT_MINUTES - 1440)); fi

	if [[ $CURRENT_MINUTES -gt $LAST_THIRD_MINUTES ]]; then
		CURRENT_PRAYER="Last Third"
		NEXT_PRAYER="Fajr"

		NEXT_PRAYER_TIME="$FAJR_TIME"
		if [[ -f "$NOTIFIED_FILE" ]]; then
			NOTIFIED_PRAYER_TIME=$(cat "$NOTIFIED_FILE")
			if [[ "$CURRENT_TIME" > "$NOTIFIED_PRAYER_TIME" ]]; then rm "$NOTIFIED_FILE"; fi
		fi
	elif [[ $CURRENT_MINUTES -eq $LAST_THIRD_MINUTES ]]; then
		CURRENT_PRAYER="Last Third"
		NEXT_PRAYER="Fajr"
		NEXT_PRAYER_TIME="$FAJR_TIME"

		CURRENT_PRAYER_ARABIC=$(arabic_prayer_name "$CURRENT_PRAYER")
		notify-send --urgency=critical "حان وقت $CURRENT_PRAYER_ARABIC ($CURRENT_TIME)" -r 4
		echo "$MIDNIGHT_TIME" > "$NOTIFIED_FILE"
	elif [[ $CURRENT_MINUTES -gt $MIDNIGHT_MINUTES && $CURRENT_MINUTES -lt $LAST_THIRD_MINUTES ]]; then
		CURRENT_PRAYER="Midnight"
		NEXT_PRAYER="Last Third"
		NEXT_PRAYER_TIME="$LAST_THIRD_TIME"

		if [[ -f "$NOTIFIED_FILE" ]]; then
			NOTIFIED_PRAYER_TIME=$(cat "$NOTIFIED_FILE")
			if [[ "$CURRENT_TIME" > "$NOTIFIED_PRAYER_TIME" ]]; then rm "$NOTIFIED_FILE"; fi
		fi
	elif [[ $CURRENT_MINUTES -eq $MIDNIGHT_MINUTES ]]; then
		CURRENT_PRAYER="Midnight"
		NEXT_PRAYER="Last Third"
		NEXT_PRAYER_TIME="$LAST_THIRD_TIME"

		CURRENT_PRAYER_ARABIC=$(arabic_prayer_name "$CURRENT_PRAYER")
		notify-send --urgency=critical "حان وقت $CURRENT_PRAYER_ARABIC ($CURRENT_TIME)" -r 4
		echo "$MIDNIGHT_TIME" > "$NOTIFIED_FILE"
	elif [[ $CURRENT_MINUTES -lt $MIDNIGHT_MINUTES ]]; then
		CURRENT_PRAYER="Isha"
		NEXT_PRAYER="Midnight"
		NEXT_PRAYER_TIME="$MIDNIGHT_TIME"
	fi
fi

while IFS= read -r line; do 
	if [[ $CURRENT_MINUTES -lt $FAJR_MINUTES ]]; then break; fi

	PRAYER_NAME=$(echo "$line" | awk -F': ' '{print $1}')
	PRAYER_TIME=$(echo "$line" | awk -F': ' '{print $2}')
	PRAYER_MINUTES=$(to_mins "$PRAYER_TIME")

	if [[ $CURRENT_MINUTES -eq $PRAYER_MINUTES ]]; then
		CURRENT_PRAYER="$PRAYER_NAME"

		if [[ ! -f "$NOTIFIED_FILE" ]]; then
			# notify-send --urgency=critical "Time for $PRAYER_NAME ($PRAYER_TIME)" -r 4

			CURRENT_PRAYER_ARABIC=$(arabic_prayer_name "$CURRENT_PRAYER")
			if [[ "$CURRENT_PRAYER" =~ ^(Sunrise|Midnight|Last Third)$ ]]; then
				notify-send --urgency=critical "حان وقت $CURRENT_PRAYER_ARABIC ($CURRENT_TIME)" -r 4
			else
				notify-send --urgency=critical "حان وقت صلاة $CURRENT_PRAYER_ARABIC ($CURRENT_TIME)" -r 4
			fi

			echo "$PRAYER_TIME" > "$NOTIFIED_FILE"
		fi
	elif [[ $CURRENT_MINUTES -gt $PRAYER_MINUTES && $PRAYER_MINUTES -ge $FAJR_MINUTES ]]; then
		CURRENT_PRAYER="$PRAYER_NAME"

		if [[ "$CURRENT_PRAYER" == "Midnight" ]]; then
			NEXT_PRAYER="Last Third"
			NEXT_PRAYER_TIME=$(awk -F: '/Last Third/ {gsub(/[",]/, "", $0); gsub(/^[ \t]+/, "", $2); print $2 ":" $3}' "$PRAYER_FILE")
		fi

		if [[ -f "$NOTIFIED_FILE" ]]; then
			NOTIFIED_PRAYER_TIME=$(cat "$NOTIFIED_FILE")
			if [[ "$CURRENT_TIME" > "$NOTIFIED_PRAYER_TIME" ]]; then rm "$NOTIFIED_FILE"; fi
		fi
	elif [[ $CURRENT_MINUTES -lt $PRAYER_MINUTES ]]; then
		NEXT_PRAYER="$PRAYER_NAME"
		NEXT_PRAYER_TIME="$PRAYER_TIME"
		break
	fi
done < <(grep -v '^#' "$PRAYER_FILE")

if [[ -z "$NEXT_PRAYER" && "$CURRENT_PRAYER" == "Isha" ]]; then
	MIDNIGHT_TIME=$(awk -F: '/Midnight/ {gsub(/[",]/, "", $0); gsub(/^[ \t]+/, "", $2); print $2 ":" $3}' "$PRAYER_FILE")

	NEXT_PRAYER="Midnight"
	NEXT_PRAYER_TIME="$MIDNIGHT_TIME"
fi

# Options:
# -p: _P_rayer module text
# -l: Infinite _l_oop of prayer module text
# -n: Current prayer time (_N_ow)
# -h: _H_ijri date
# -t: _T_ime module text (infinite loop)

if [[ "$1" == "-p" ]]; then
	CURRENT_PRAYER_ARABIC=$(arabic_prayer_name "$CURRENT_PRAYER")

	if [[ -z "$NEXT_PRAYER" ]]; then
		printf "{\"text\": \"$CURRENT_PRAYER_ARABIC\", \"alt\": \"$CURRENT_PRAYER\" }"
	else
		NEXT_PRAYER_ARABIC=$(arabic_prayer_name "$NEXT_PRAYER")

		TIME_REMAINING=$(duration $CURRENT_TIME $NEXT_PRAYER_TIME)
		TIME_REMAINING_ARABIC=$(duration $CURRENT_TIME $NEXT_PRAYER_TIME "ar")

		NEXT_PRAYER_TIME_ARABIC=$(echo $NEXT_PRAYER_TIME | to_arabic_num)

		# Arabic Tooltip
		if [[ "$NEXT_PRAYER" =~ ^(Sunrise|Midnight|Last Third)$ ]]; then
			tooltip="$NEXT_PRAYER_ARABIC بعد $TIME_REMAINING_ARABIC ($NEXT_PRAYER_TIME_ARABIC)"
		else
			tooltip="صلاة $NEXT_PRAYER_ARABIC بعد $TIME_REMAINING_ARABIC ($NEXT_PRAYER_TIME_ARABIC)"
		fi

		printf "{\"text\": \"$CURRENT_PRAYER_ARABIC\", \"alt\": \"$CURRENT_PRAYER\", \"tooltip\": \"$tooltip\" }"

		# English Tooltip
		# printf "{\"text\": \"$CURRENT_PRAYER_ARABIC\", \"alt\": \"$CURRENT_PRAYER\", \"tooltip\": \"$NEXT_PRAYER in $TIME_REMAINING ($NEXT_PRAYER_TIME)\" }"
	fi
elif [[ "$1" == "-l" ]]; then
	# Infinite loop updating prayer module every minute
	while true; do
		printf "$($HOME/.config/hypr/scripts/prayer.sh -p)\n"

		sleep $(echo "60 - $(date +%S.%N) % 60" | bc)
	done
elif [[ "$1" == "-n" ]]; then
	printf "$CURRENT_PRAYER"
elif [[ "$1" == "-h" ]]; then
	echo "$(get_hijri)"
elif [[ "$1" == "-t" ]]; then
	# Infinite loop updating time and date as soon as they change
	while true; do
		hijri_date=$(get_hijri)
		english_date="<span font='16' rise='-2000'></span> $(date +'%H:%M') <span font='16' rise='-2000'></span> $(date +'%a, %d %B %Y')"
		arabic_date="$(date +'%H:%M' | to_arabic_num) <span font='16' rise='-2000'></span> $hijri_date <span font='16' rise='-2000'></span>"

		printf "{\"text\": \"$english_date\", \"alt\": \"$arabic_date\", \"tooltip\": \"$hijri_date\" }\n"

		sleep $(echo "60 - $(date +%S.%N) % 60" | bc)
	done
else
	grep -v '^#' "$PRAYER_FILE"
fi

