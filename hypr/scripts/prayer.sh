#!/bin/bash

COUNTRY="__COUNTRY__"
CITY="__CITY__"

CURRENT_TIME=$(date +"%H:%M")
CURRENT_DATE=$(date +"%d-%m-%Y")

if [[ ! -f "$HOME/.config/prayerhistory/$CURRENT_DATE.txt" ]]; then
	TIMINGS=$(curl -Ls "http://api.aladhan.com/v1/timingsByCity?country=$COUNTRY&city=$CITY&method=4&adjustment=1" | jq ".data.timings" | sed "1d;6d;9,13d")
	echo "$TIMINGS" > "$HOME/.config/prayerhistory/$CURRENT_DATE.txt"
fi

duration() {
	time_diff=$(($(date -d "$2" +%s) - $(date -d "$1" +%s)))
	hours=$((time_diff / 3600))
	minutes=$(((time_diff % 3600) / 60))
	
	if ((hours == 0)); then printf "$minutes mins"; else printf '%02d:%02d\n' "$hours" "$minutes"; fi
}

while IFS= read -r line; do 
	PRAYER_NAME=$(echo $line | awk '{print $1}' | cut -d '"' -f2)
	PRAYER_TIME=$(echo $line | awk '{print $2}' | cut -d '"' -f2)
	
	if [[ "$CURRENT_TIME" == "$PRAYER_TIME" ]]; then
		CURRENT_PRAYER="$PRAYER_NAME"
		
		if [[ ! -f "$HOME/.config/prayerhistory/notified" ]]; then
			notify-send --urgency=critical "Time for $PRAYER_NAME ($PRAYER_TIME)" -r 3
			touch "$HOME/.config/prayerhistory/notified"
		fi
	elif [[ "$CURRENT_TIME" > "$PRAYER_TIME" ]]; then
		CURRENT_PRAYER="$PRAYER_NAME"
		if [[ -f "$HOME/.config/prayerhistory/notified" ]] then rm "$HOME/.config/prayerhistory/notified"; fi
	elif [[ "$CURRENT_TIME" < "$PRAYER_TIME" ]]; then
		NEXT_PRAYER="$PRAYER_NAME"
		NEXT_PRAYER_TIME="$PRAYER_TIME"
		break
	fi
done < "$HOME/.config/prayerhistory/$CURRENT_DATE.txt"

if [[ -z "$CURRENT_PRAYER" ]]; then
	CURRENT_PRAYER="Qiyam"
fi

if [[ "$1" == "-b" ]]; then
	if [[ -z "$NEXT_PRAYER" ]]; then
		printf "$CURRENT_PRAYER"
	else
		TIME_REMAINING=$(duration $CURRENT_TIME $NEXT_PRAYER_TIME)
		printf "$CURRENT_PRAYER\n$NEXT_PRAYER in $TIME_REMAINING ($NEXT_PRAYER_TIME)"
	fi
elif [[ "$1" == "-n" ]]; then
	printf "$CURRENT_PRAYER"
elif [[ "$1" == "-h" ]]; then
	today=$(curl -Ls "https://api.aladhan.com/v1/gToH/$CURRENT_DATE" | jq .data.hijri)
	day=$(echo $today | jq .day)
	month=$(echo $today | jq .month.en)
	year=$(echo $today | jq .year)
	
	printf "$(date +%a), ${day//\"/} ${month//\"/} ${year//\"/}"
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

