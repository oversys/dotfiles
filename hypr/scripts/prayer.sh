#!/bin/bash

# Country name or ISO 3166 code (ex: Netherlands or NL)
COUNTRY="__COUNTRY__"
CITY="__CITY__"

# 3 - Muslim World League
# 4 - Umm Al-Qura University, Makkah
# 8 - Gulf Region
# 16 - Dubai (unofficial)
METHOD="__METHOD__"

CURRENT_TIME=$(date +"%H:%M")
CURRENT_DATE=$(date +"%d-%m-%Y")
NOTIFIED_FILE="$HOME/.config/prayerhistory/notified"
HIJRI_FILE="$HOME/.config/prayerhistory/hijri.txt"

if [[ ! -f "$HOME/.config/prayerhistory/$CURRENT_DATE.txt" ]]; then
	TIMINGS=$(curl -Ls "http://api.aladhan.com/v1/timingsByCity?country=$COUNTRY&city=$CITY&method=$METHOD&adjustment=1" | jq ".data.timings" | sed "1d;6d;9,13d")
	if [ -n "$TIMINGS" ]; then echo "$TIMINGS" | awk '{$1=$1; print}' > "$HOME/.config/prayerhistory/$CURRENT_DATE.txt"; fi
fi

indo_arabic_numerals() {
	read western_arabic
	echo $western_arabic | sed -e 's/0/٠/g' -e 's/1/١/g' -e 's/2/٢/g' -e 's/3/٣/g' -e 's/4/٤/g' -e 's/5/٥/g' -e 's/6/٦/g' -e 's/7/٧/g' -e 's/8/٨/g' -e 's/9/٩/g'
}

arabic_prayer_name() {
	case "$1" in
		"Fajr") PRAYER_ARABIC="الفجر";;
		"Dhuhr") PRAYER_ARABIC="الظهر";;
		"Asr") PRAYER_ARABIC="العصر";;
		"Maghrib") PRAYER_ARABIC="المغرب";;
		"Isha") PRAYER_ARABIC="العشاء";;
	esac

	echo "$PRAYER_ARABIC"
}

duration() {
	time_diff=$(($(date -d "$2" +%s) - $(date -d "$1" +%s)))
	hours=$((time_diff / 3600))
	minutes=$(((time_diff % 3600) / 60))

	if [[ "$3" == "ar" ]]; then
		if ((hours == 0)); then
			if ((minutes == 2)); then minutes_text="دقيقتان";
			elif ((minutes <= 10 && minutes >= 3)); then minutes_text="دقائق";
			else minutes_text="دقيقة"; fi

			if ((minutes <= 2)); then
				printf "$minutes_text";
			else
				printf "$(echo $minutes | indo_arabic_numerals) $minutes_text"; 
			fi
		else
			printf '%02d:%02d\n' "$hours" "$minutes" | indo_arabic_numerals
		fi
	else
		if ((hours == 0)); then
			if ((minutes == 1)); then printf "$minutes min"; else printf "$minutes mins"; fi
		else
			printf '%02d:%02d\n' "$hours" "$minutes"
		fi
	fi
}

while IFS= read -r line; do 
	PRAYER_NAME=$(echo $line | awk -F'"' '{print $2}')
	PRAYER_TIME=$(echo $line | awk -F'"' '{print $4}')

	if [[ "$CURRENT_TIME" == "$PRAYER_TIME" ]]; then
		CURRENT_PRAYER="$PRAYER_NAME"

		if [[ ! -f "$NOTIFIED_FILE" ]]; then
			notify-send --urgency=critical "Time for $PRAYER_NAME ($PRAYER_TIME)" -r 3
			echo "$PRAYER_TIME" > "$NOTIFIED_FILE"
		fi
	elif [[ "$CURRENT_TIME" > "$PRAYER_TIME" ]]; then
		CURRENT_PRAYER="$PRAYER_NAME"

		if [[ -f "$NOTIFIED_FILE" ]]; then
			NOTIFIED_PRAYER_TIME=$(cat "$NOTIFIED_FILE")
			if [[ "$CURRENT_TIME" > "$NOTIFIED_PRAYER_TIME" ]]; then rm "$NOTIFIED_FILE"; fi
		fi
	elif [[ "$CURRENT_TIME" < "$PRAYER_TIME" ]]; then
		NEXT_PRAYER="$PRAYER_NAME"
		NEXT_PRAYER_TIME="$PRAYER_TIME"
		break
	fi
done < "$HOME/.config/prayerhistory/$CURRENT_DATE.txt"

if [[ -z "$CURRENT_PRAYER" ]]; then
	CURRENT_PRAYER="Qiyam"
fi

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

		NEXT_PRAYER_TIME_ARABIC=$(echo $NEXT_PRAYER_TIME | indo_arabic_numerals)

		# Arabic Tooltip
		printf "{\"text\": \"$CURRENT_PRAYER_ARABIC\", \"alt\": \"$CURRENT_PRAYER\", \"tooltip\": \"صلاة $NEXT_PRAYER_ARABIC بعد $TIME_REMAINING_ARABIC ($NEXT_PRAYER_TIME_ARABIC)\" }"

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
		date=$(echo $converter | jq -r ".result.hijri.[1]" | indo_arabic_numerals)
		today="$(echo $converter | jq -r .day)، $date"

		echo "$CURRENT_DATE $today" > "$HIJRI_FILE"
	else
		today=$LAST_HIJRI
	fi

	if [[ "$1" == "-h" ]]; then
		echo "$today"
	else
		english_date="<span font='16' rise='-2000'></span> $(date +'%H:%M') <span font='16' rise='-2000'></span> $(date +'%a, %d %B %Y')"
		arabic_date="$(date +'%H:%M' | indo_arabic_numerals) <span font='16' rise='-2000'></span> $today <span font='16' rise='-2000'></span>"

		printf "{\"text\": \"$english_date\", \"alt\": \"$arabic_date\", \"tooltip\": \"$today\" }"
	fi
else
	cat "$HOME/.config/prayerhistory/$CURRENT_DATE.txt"
	echo "Current prayer: $CURRENT_PRAYER"

	if [[ -n "$NEXT_PRAYER" ]]; then
		TIME_REMAINING=$(duration $CURRENT_TIME $NEXT_PRAYER_TIME)
		echo "Next prayer: $NEXT_PRAYER in $TIME_REMAINING"
	else
		echo "Next prayer: $NEXT_PRAYER"
	fi
fi

