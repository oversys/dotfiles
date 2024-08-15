#!/bin/bash

## LOCATION - If country or city are not entered then location will be fetched automatically

# Country name or ISO 3166 code (ex: Netherlands or NL)
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
NOTIFIED_FILE="$PRAYER_DIR/notified"
HIJRI_FILE="$PRAYER_DIR/hijri.txt"

# Automatically detect location
if [[ "$COUNTRY" == "__COUNTRY__" || -z "$COUNTRY" || "$CITY" == "__CITY__" || -z "$CITY" ]] && [[ ! -f "$PRAYER_FILE" ]]; then
	LOCATION=$(curl -s https://ipinfo.io)
	COUNTRY="$(echo $LOCATION | jq -r '.country')"
	CITY="$(echo $LOCATION | jq -r '.city')"
fi

# Default method
if [[ "$METHOD" == "__METHOD__" ]]; then METHOD=3; fi

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

CURRENT_MINUTES=$(to_mins "$CURRENT_TIME")

if [[ ! -f "$PRAYER_FILE" ]]; then
	TIMINGS=$(curl -Ls "http://api.aladhan.com/v1/timingsByCity?country=$COUNTRY&city=$CITY&method=$METHOD" | jq -r '.data.timings | {Midnight, "Last Third": .Lastthird, Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha} | to_entries | map("\(.key): \(.value)") | .[]')

	if [ -n "$TIMINGS" ]; then echo "$TIMINGS" > "$PRAYER_FILE"; fi
fi

FAJR_TIME=$(awk -F: '/Fajr/ {gsub(/[",]/, "", $0); gsub(/^[ \t]+/, "", $2); print $2 ":" $3}' "$PRAYER_FILE")
FAJR_MINUTES=$(to_mins "$FAJR_TIME")

if [[ $CURRENT_MINUTES -lt $FAJR_MINUTES ]]; then
	CURRENT_DATE=$YESTERDAY_DATE
	PRAYER_FILE="$PRAYER_DIR/$CURRENT_DATE.txt"

	NEXT_PRAYER="Fajr"
	NEXT_PRAYER_TIME="$FAJR_TIME"

	if [[ ! -f "$PRAYER_FILE" ]]; then
		TIMINGS=$(curl -Ls "http://api.aladhan.com/v1/timingsByCity/$CURRENT_DATE?country=$COUNTRY&city=$CITY&method=$METHOD" | jq -r '.data.timings | {Midnight, "Last Third": .Lastthird, Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha} | to_entries | map("\(.key): \(.value)") | .[]')

		if [ -n "$TIMINGS" ]; then echo "$TIMINGS" > "$PRAYER_FILE"; fi
	fi
fi

while IFS= read -r line; do 
	PRAYER_NAME=$(echo "$line" | awk -F': ' '{print $1}')
	PRAYER_TIME=$(echo "$line" | awk -F': ' '{print $2}')
	PRAYER_MINUTES=$(to_mins "$PRAYER_TIME")

	if [[ $CURRENT_MINUTES -eq $PRAYER_MINUTES ]]; then
		CURRENT_PRAYER="$PRAYER_NAME"

		if [[ ! -f "$NOTIFIED_FILE" ]]; then
			# notify-send --urgency=critical "Time for $PRAYER_NAME ($PRAYER_TIME)" -r 3

			CURRENT_PRAYER_ARABIC=$(arabic_prayer_name "$CURRENT_PRAYER")
			if [[ "$CURRENT_PRAYER" =~ ^(Sunrise|Midnight|Last Third)$ ]]; then
				notify-send --urgency=critical "حان وقت $CURRENT_PRAYER_ARABIC ($PRAYER_TIME)" -r 3
			else
				notify-send --urgency=critical "حان وقت صلاة $CURRENT_PRAYER_ARABIC ($PRAYER_TIME)" -r 3
			fi

			echo "$PRAYER_TIME" > "$NOTIFIED_FILE"
		fi
	elif [[ $CURRENT_MINUTES -gt $PRAYER_MINUTES ]]; then
		CURRENT_PRAYER="$PRAYER_NAME"

		if [[ -f "$NOTIFIED_FILE" ]]; then
			NOTIFIED_PRAYER_TIME=$(cat "$NOTIFIED_FILE")
			if [[ "$CURRENT_TIME" > "$NOTIFIED_PRAYER_TIME" ]]; then rm "$NOTIFIED_FILE"; fi
		fi
	elif [[ $CURRENT_MINUTES -lt $PRAYER_MINUTES && "$CURRENT_PRAYER" != "Last Third" ]]; then
		NEXT_PRAYER="$PRAYER_NAME"
		NEXT_PRAYER_TIME="$PRAYER_TIME"
		break
	fi
done < "$PRAYER_FILE"

if [[ -z "$NEXT_PRAYER" && "$CURRENT_PRAYER" == "Isha" ]]; then
	MIDNIGHT_TIME=$(awk -F: '/Midnight/ {gsub(/[",]/, "", $0); gsub(/^[ \t]+/, "", $2); print $2 ":" $3}' "$PRAYER_FILE")

	NEXT_PRAYER="Midnight"
	NEXT_PRAYER_TIME="$MIDNIGHT_TIME"
fi

if [[ -z "$CURRENT_PRAYER" && "$NEXT_PRAYER" == "Midnight" ]]; then CURRENT_PRAYER="Isha"; fi

# Options:
# -p: _P_rayer module text
# -n: Current prayer time (_N_ow)
# -h: _H_ijri date
# -t: _T_ime module text

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
elif [[ "$1" == "-n" ]]; then
	printf "$CURRENT_PRAYER"
elif [[ "$1" =~ ^(-h|-t)$ ]]; then
	# Using aladhan.com
	#
	# today=$(curl -Ls "https://api.aladhan.com/v1/gToH/$CURRENT_DATE" | jq .data.hijri)
	# day=$(echo $today | jq -r .day)
	# month=$(echo $today | jq -r .month.en)
	# year=$(echo $today | jq -r .year)
	#
	# printf "$(date +%a), $day $month $year"

	# Using datehijri.com

	if [[ ! -f "$HIJRI_FILE" ]]; then touch "$HIJRI_FILE"; fi

	read -r LAST_DATE LAST_HIJRI < "$HIJRI_FILE"

	if [ "$LAST_DATE" != "$CURRENT_DATE" ]; then
		converter=$(curl -s https://datehijri.com/ajax.php | jq -r .converter)
		date=$(echo $converter | jq -r ".result.hijri.[1]" | to_arabic_num)
		today="$(echo $converter | jq -r .day)، $date"

		if [ -n "$converter" ]; then echo "$CURRENT_DATE $today" > "$HIJRI_FILE"; fi
	else
		today=$LAST_HIJRI
	fi

	if [[ "$1" == "-h" ]]; then
		echo "$today"
	else
		english_date="<span font='16' rise='-2000'></span> $(date +'%H:%M') <span font='16' rise='-2000'></span> $(date +'%a, %d %B %Y')"
		arabic_date="$(date +'%H:%M' | to_arabic_num) <span font='16' rise='-2000'></span> $today <span font='16' rise='-2000'></span>"

		printf "{\"text\": \"$english_date\", \"alt\": \"$arabic_date\", \"tooltip\": \"$today\" }"
	fi
else
	awk '
		/Midnight/ { midnight = $0; next }
		/Last Third/ { lastthird = $0; next }
		{ print }
		END {
			if (midnight) print midnight
			if (lastthird) print lastthird
		}' "$PRAYER_FILE"
fi

