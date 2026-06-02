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
NOW_DATE=$(date +"%d-%m-%Y")
NOW_EPOCH=$(date +"%s")
YESTERDAY_DATE=$(date -d "yesterday" +"%d-%m-%Y")

# Files & Directories
PRAYER_DIR="$HOME/.config/prayerhistory"
CACHE_FILE="$PRAYER_DIR/${MASJID_ID}.json"
NOTIFIED_FILE="$PRAYER_DIR/notified"
HIJRI_FILE="$PRAYER_DIR/hijri.txt"

# Default method
if [[ "$METHOD" == "__METHOD__" || -z "$METHOD" ]]; then
	METHOD=3
fi

# Helper Functions

to_arabic_num() {
	sed 'y/0123456789/٠١٢٣٤٥٦٧٨٩/'
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

extract_time() {
	local cycle_date="$1"
	local prayer_name="$2"

	awk -F': ' -v prayer_name="$prayer_name" '$1 == prayer_name {print $2}' "$PRAYER_DIR/$cycle_date.txt" | tr -d '", \t'
}

# Convert $1=DD-MM-YYYY $2=HH:MM to Unix Epoch seconds
to_epoch() {
	local date_str="$1"
	local time_str="$2"
	local formatted_date=$(echo "$date_str" | awk -F'-' '{print $3"-"$2"-"$1}')
	date -d "$formatted_date $time_str" +"%s"
}

duration() {
	local start_seconds="$1"
	local end_seconds="$2"
	local lang="$3"
	local diff_seconds=$((end_seconds - start_seconds))
	local hours=$((diff_seconds / 3600))
	local minutes=$(( (diff_seconds % 3600) / 60 ))

	if [[ "$lang" == "ar" ]]; then
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
		local conf_data=$(echo "$response" | grep -oP '(var|let) confData = \K.*(?=;)')

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
	local REQ_DATE="$1"
	local PRAYER_FILE="$PRAYER_DIR/$REQ_DATE.txt"

	if [[ -s "$PRAYER_FILE" ]]; then
		return 0
	fi

	local TIMES=""
	local SOURCE_COMMENT=""

	if [[ "$MASJID_ID" == "__MASJID_ID__" || -z "$MASJID_ID" ]]; then
		if [[ "$COUNTRY" != "__COUNTRY__" && -n "$COUNTRY" && "$CITY" != "__CITY__" && -n "$CITY" ]]; then
			SOURCE_COMMENT="# Fetched prayer times from api.aladhan.com with given location: $CITY, $COUNTRY"
		else
			# Automatically detect location if neither masjid ID nor location are provided
			local LOCATION=$(curl -s https://ipinfo.io)
			COUNTRY="$(echo $LOCATION | jq -r '.country')"
			CITY="$(echo $LOCATION | jq -r '.city')"

			SOURCE_COMMENT="# Fetched prayer times from api.aladhan.com with automatically detected location: $CITY, $COUNTRY"
		fi

		# Fetch times from api.aladhan.com
		TIMES=$(curl -Ls "http://api.aladhan.com/v1/timingsByCity/$REQ_DATE?country=$COUNTRY&city=$CITY&method=$METHOD" | jq -r '[.data.timings.Fajr, .data.timings.Sunrise, .data.timings.Dhuhr, .data.timings.Asr, .data.timings.Maghrib, .data.timings.Isha]')
	else
		# Fetch times from mawaqit.net
		local DAY=$(echo "$REQ_DATE" | awk -F'-' '{print $1 + 0}')
		local MONTH=$(echo "$REQ_DATE" | awk -F'-' '{print $2 - 1}')

		if [[ $USE_CACHE -eq 1 && -f "$CACHE_FILE" ]]; then
			# Use cached calendar
			SOURCE_COMMENT="# Fetched prayer times from mawaqit.net with masjid ID: \"$MASJID_ID\" (local cache)"
			TIMES=$(jq -r ".calendar[$MONTH][\"$DAY\"]" "$CACHE_FILE")
		else
			local RESPONSE=$(fetch_mawaqit "$MASJID_ID")

			if [[ $USE_CACHE -eq 1 ]]; then
				echo "$RESPONSE" > "$CACHE_FILE"
			fi

			SOURCE_COMMENT="# Fetched prayer times from mawaqit.net with masjid ID: \"$MASJID_ID\""
			TIMES=$(echo "$RESPONSE" | jq -r ".calendar[$MONTH][\"$DAY\"]")
		fi
	fi

	FINAL_TIMINGS=$(echo "$TIMES" | jq -r \
		'{
			Fajr: .[0],
			Sunrise: .[1],
			Dhuhr: .[2],
			Asr: .[3],
			Maghrib: .[4],
			Isha: .[5]
		} | to_entries | map("\(.key): \(.value)") | .[]')

	if [ -n "$FINAL_TIMINGS" ]; then
		echo "$SOURCE_COMMENT" > "$PRAYER_FILE"
		echo "$FINAL_TIMINGS" >> "$PRAYER_FILE"
	fi
}

get_hijri() {
	if [[ ! -f "$HIJRI_FILE" ]]; then
		touch "$HIJRI_FILE"
	fi

	read -r LAST_DATE LAST_HIJRI < "$HIJRI_FILE"

	if [ "$LAST_DATE" != "$NOW_DATE" ]; then
		local new_hijri=""

		if command -v node >/dev/null 2>&1; then
			new_hijri=$(node -e "console.log(new Date().toLocaleDateString('ar-SA-u-ca-islamic', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' }))" | sed "s/ هـ//")
		else
			today=$(curl -Ls "https://api.aladhan.com/v1/gToH/$NOW_DATE" | jq .data.hijri)
			day=$(echo $today | jq -r .day)
			month=$(echo $today | jq -r .month.en)
			year=$(echo $today | jq -r .year)

			new_hijri="$(date +%a), $day $month $year"
		fi

		if [ -n "$new_hijri" ]; then
			echo "$NOW_DATE $new_hijri" > "$HIJRI_FILE"
			echo "$new_hijri"
		else
			echo "$LAST_HIJRI"
		fi
	else
		echo "$LAST_HIJRI"
	fi
}

# Determine cycle (from Fajr to Fajr)
get_timings "$NOW_DATE"

TODAY_FAJR_EPOCH=$(to_epoch "$NOW_DATE" "$(extract_time "$NOW_DATE" "Fajr")")

if (( NOW_EPOCH < TODAY_FAJR_EPOCH )); then
	CYCLE_DATE="$YESTERDAY_DATE"
	NEXT_CYCLE_DATE="$NOW_DATE"
else
	CYCLE_DATE="$NOW_DATE"
	NEXT_CYCLE_DATE="$(date -d "tomorrow" +"%d-%m-%Y")"
fi

# Ensure prayer times exist
get_timings "$CYCLE_DATE"
get_timings "$NEXT_CYCLE_DATE"

# Extract prayer times
CYCLE_FAJR=$(to_epoch "$CYCLE_DATE" "$(extract_time "$CYCLE_DATE" "Fajr")")
CYCLE_SUNRISE=$(to_epoch "$CYCLE_DATE" "$(extract_time "$CYCLE_DATE" "Sunrise")")
CYCLE_DHUHR=$(to_epoch "$CYCLE_DATE" "$(extract_time "$CYCLE_DATE" "Dhuhr")")
CYCLE_ASR=$(to_epoch "$CYCLE_DATE" "$(extract_time "$CYCLE_DATE" "Asr")")
CYCLE_MAGHRIB=$(to_epoch "$CYCLE_DATE" "$(extract_time "$CYCLE_DATE" "Maghrib")")

CYCLE_ISHA=$(to_epoch "$CYCLE_DATE" "$(extract_time "$CYCLE_DATE" "Isha")")
if (( CYCLE_ISHA < CYCLE_MAGHRIB )); then
	CYCLE_ISHA=$(to_epoch "$NEXT_CYCLE_DATE" "$(extract_time "$CYCLE_DATE" "Isha")")
fi

NEXT_CYCLE_FAJR=$(to_epoch "$NEXT_CYCLE_DATE" "$(extract_time "$NEXT_CYCLE_DATE" "Fajr")")

# Calculate or extract Midnight and Last Third times
PRAYER_FILE="$PRAYER_DIR/$CYCLE_DATE.txt"

if [ -z "$(grep 'Midnight' "$PRAYER_FILE")" ]; then
	NIGHT_DURATION=$(( NEXT_CYCLE_FAJR - CYCLE_MAGHRIB ))
	CYCLE_MIDNIGHT=$(( CYCLE_MAGHRIB + (NIGHT_DURATION / 2) ))
	CYCLE_LAST_THIRD=$(( NEXT_CYCLE_FAJR - (NIGHT_DURATION / 3) ))

	MIDNIGHT_TIME=$(date -d "@$CYCLE_MIDNIGHT" +"%H:%M")
	LAST_THIRD_TIME=$(date -d "@$CYCLE_LAST_THIRD" +"%H:%M")

	echo "Midnight: $MIDNIGHT_TIME" >> "$PRAYER_FILE"
	echo "Last Third: $LAST_THIRD_TIME" >> "$PRAYER_FILE"
else
	CYCLE_MIDNIGHT=$(to_epoch "$CYCLE_DATE" "$(extract_time "$CYCLE_DATE" "Midnight")")
	if (( CYCLE_MIDNIGHT < CYCLE_MAGHRIB )); then
		CYCLE_MIDNIGHT=$(to_epoch "$NEXT_CYCLE_DATE" "$(extract_time "$CYCLE_DATE" "Midnight")")
	fi

	CYCLE_LAST_THIRD=$(to_epoch "$CYCLE_DATE" "$(extract_time "$CYCLE_DATE" "Last Third")")
	if (( CYCLE_LAST_THIRD < CYCLE_MAGHRIB )); then
		CYCLE_LAST_THIRD=$(to_epoch "$NEXT_CYCLE_DATE" "$(extract_time "$CYCLE_DATE" "Last Third")")
	fi
fi

# Determine current and next prayers
if (( NOW_EPOCH >= CYCLE_FAJR && NOW_EPOCH < CYCLE_SUNRISE )); then
	CURRENT_PRAYER="Fajr"
	CURRENT_PRAYER_EPOCH="$CYCLE_FAJR"
	NEXT_PRAYER="Sunrise"
	NEXT_PRAYER_EPOCH="$CYCLE_SUNRISE"
elif (( NOW_EPOCH >= CYCLE_SUNRISE && NOW_EPOCH < CYCLE_DHUHR )); then
	CURRENT_PRAYER="Sunrise"
	CURRENT_PRAYER_EPOCH="$CYCLE_SUNRISE"
	NEXT_PRAYER="Dhuhr"
	NEXT_PRAYER_EPOCH="$CYCLE_DHUHR"
elif (( NOW_EPOCH >= CYCLE_DHUHR && NOW_EPOCH < CYCLE_ASR )); then
	CURRENT_PRAYER="Dhuhr"
	CURRENT_PRAYER_EPOCH="$CYCLE_DHUHR"
	NEXT_PRAYER="Asr"
	NEXT_PRAYER_EPOCH="$CYCLE_ASR"
elif (( NOW_EPOCH >= CYCLE_ASR && NOW_EPOCH < CYCLE_MAGHRIB )); then
	CURRENT_PRAYER="Asr"
	CURRENT_PRAYER_EPOCH="$CYCLE_ASR"
	NEXT_PRAYER="Maghrib"
	NEXT_PRAYER_EPOCH="$CYCLE_MAGHRIB"
elif (( NOW_EPOCH >= CYCLE_MAGHRIB && NOW_EPOCH < CYCLE_ISHA )); then
	CURRENT_PRAYER="Maghrib"
	CURRENT_PRAYER_EPOCH="$CYCLE_MAGHRIB"
	NEXT_PRAYER="Isha"
	NEXT_PRAYER_EPOCH="$CYCLE_ISHA"
elif (( NOW_EPOCH >= CYCLE_ISHA && NOW_EPOCH < CYCLE_MIDNIGHT )); then
	CURRENT_PRAYER="Isha"
	CURRENT_PRAYER_EPOCH="$CYCLE_ISHA"
	NEXT_PRAYER="Midnight"
	NEXT_PRAYER_EPOCH="$CYCLE_MIDNIGHT"
elif (( NOW_EPOCH >= CYCLE_MIDNIGHT && NOW_EPOCH < CYCLE_LAST_THIRD )); then
	CURRENT_PRAYER="Midnight"
	CURRENT_PRAYER_EPOCH="$CYCLE_MIDNIGHT"
	NEXT_PRAYER="Last Third"
	NEXT_PRAYER_EPOCH="$CYCLE_LAST_THIRD"
elif (( NOW_EPOCH >= CYCLE_LAST_THIRD && NOW_EPOCH < NEXT_CYCLE_FAJR )); then
	CURRENT_PRAYER="Last Third"
	CURRENT_PRAYER_EPOCH="$CYCLE_LAST_THIRD"
	NEXT_PRAYER="Fajr"
	NEXT_PRAYER_EPOCH="$NEXT_CYCLE_FAJR"
fi

CURRENT_PRAYER_NOTIFICATION="$CYCLE_DATE $CURRENT_PRAYER"
LAST_NOTIFIED=$(cat "$NOTIFIED_FILE" 2>/dev/null)

if [[ "$LAST_NOTIFIED" != "$CURRENT_PRAYER_NOTIFICATION" ]]; then
	CURRENT_PRAYER_ARABIC=$(arabic_prayer_name "$CURRENT_PRAYER")
	CURRENT_PRAYER_TIME=$(date -d "@$CURRENT_PRAYER_EPOCH" +"%H:%M")
	CURRENT_PRAYER_TIME_ARABIC=$(echo $CURRENT_PRAYER_TIME | to_arabic_num)

	if [[ "$CURRENT_PRAYER" =~ ^(Sunrise|Midnight|Last Third)$ ]]; then
		notify-send --urgency=critical "حان وقت $CURRENT_PRAYER_ARABIC ($CURRENT_PRAYER_TIME_ARABIC)" -r 4
	else
		notify-send --urgency=critical "حان وقت صلاة $CURRENT_PRAYER_ARABIC ($CURRENT_PRAYER_TIME_ARABIC)" -r 4
	fi

	echo "$CURRENT_PRAYER_NOTIFICATION" > "$NOTIFIED_FILE"
fi

# Options:
# -p: _P_rayer module text
# -l: Infinite _l_oop of prayer module text
# -n: Current prayer time (_N_ow)
# -h: _H_ijri date
# -t: _T_ime module text (infinite loop)

if [[ "$1" == "-p" ]]; then
	CURRENT_PRAYER_ARABIC=$(arabic_prayer_name "$CURRENT_PRAYER")

	NEXT_PRAYER_ARABIC=$(arabic_prayer_name "$NEXT_PRAYER")
	NEXT_PRAYER_TIME=$(date -d "@$NEXT_PRAYER_EPOCH" +"%H:%M")
	NEXT_PRAYER_TIME_ARABIC=$(echo $NEXT_PRAYER_TIME | to_arabic_num)

	TIME_REMAINING_ARABIC=$(duration $NOW_EPOCH $NEXT_PRAYER_EPOCH "ar")

	# Arabic Tooltip
	if [[ "$NEXT_PRAYER" =~ ^(Sunrise|Midnight|Last Third)$ ]]; then
		tooltip="$NEXT_PRAYER_ARABIC بعد $TIME_REMAINING_ARABIC ($NEXT_PRAYER_TIME_ARABIC)"
	else
		tooltip="صلاة $NEXT_PRAYER_ARABIC بعد $TIME_REMAINING_ARABIC ($NEXT_PRAYER_TIME_ARABIC)"
	fi

	printf "{\"text\": \"$CURRENT_PRAYER_ARABIC\", \"alt\": \"$CURRENT_PRAYER\", \"tooltip\": \"$tooltip\" }"
elif [[ "$1" == "-l" ]]; then
	# Infinite loop updating prayer module every minute
	while true; do
		printf "$($HOME/.config/scripts/prayer.sh -p)\n"

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
	FAJR_TIME=$(extract_time "$CYCLE_DATE" "Fajr")
	SUNRISE_TIME=$(extract_time "$CYCLE_DATE" "Sunrise")
	DHUHR_TIME=$(extract_time "$CYCLE_DATE" "Dhuhr")
	ASR_TIME=$(extract_time "$CYCLE_DATE" "Asr")
	MAGHRIB_TIME=$(extract_time "$CYCLE_DATE" "Maghrib")
	ISHA_TIME=$(extract_time "$CYCLE_DATE" "Isha")
	MIDNIGHT_TIME=$(extract_time "$CYCLE_DATE" "Midnight")
	LAST_THIRD_TIME=$(extract_time "$CYCLE_DATE" "Last Third")

	# Left-to-Right mark for Arabic
	LRM=$'\u200E'

	echo "Fajr:       $FAJR_TIME ———————————————————— $(echo $FAJR_TIME | to_arabic_num)      :$LRMالفجر$LRM"
	echo "Sunrise:    $SUNRISE_TIME ———————————————————— $(echo $SUNRISE_TIME | to_arabic_num)     :$LRMالشروق$LRM"
	echo "Dhuhr:      $DHUHR_TIME ———————————————————— $(echo $DHUHR_TIME | to_arabic_num)      :$LRMالظهر$LRM"
	echo "Asr:        $ASR_TIME ———————————————————— $(echo $ASR_TIME | to_arabic_num)      :$LRMالعصر$LRM"
	echo "Maghrib:    $MAGHRIB_TIME ———————————————————— $(echo $MAGHRIB_TIME | to_arabic_num)     :$LRMالمغرب$LRM"
	echo "Isha:       $ISHA_TIME ———————————————————— $(echo $ISHA_TIME | to_arabic_num)     :$LRMالعشاء$LRM"
	echo "Midnight:   $MIDNIGHT_TIME ———————————————————— $(echo $MIDNIGHT_TIME | to_arabic_num) :$LRMمنتصف الليل$LRM"
	echo "Last Third: $LAST_THIRD_TIME ———————————————————— $(echo $LAST_THIRD_TIME | to_arabic_num)  :$LRMالثلث الأخير$LRM"
fi

