#!/bin/bash

PREV_BLUE_DEV=$(bluetoothctl info | grep -oP 'Name: \K.*')

while sleep 3; do
	BLUE_DEV=$(bluetoothctl info | grep -oP 'Name: \K.*')

	if [[ -n $BLUE_DEV && -z $PREV_BLUE_DEV ]]; then
		notify-send "󰥰 Connected: $BLUE_DEV" -r 1
	elif [[ -z $BLUE_DEV && -n $PREV_BLUE_DEV ]]; then
		notify-send "󰽟 Disconnected: $PREV_BLUE_DEV" -r 1
	fi

	PREV_BLUE_DEV=$BLUE_DEV

	CUR_BAT=$(cat /sys/class/power_supply/BAT*/capacity)
	BAT_STAT=$(cat /sys/class/power_supply/BAT*/status)
	
	if [[ $BAT_STAT == "Charging" && $PREV_BAT_STAT == "Discharging" && $CUR_BAT -le 20 ]]; then
		swaync-client --close-latest
	elif [[ $BAT_STAT == "Discharging" ]]; then
		if ((CUR_BAT <= 10)) then BAT_ICON=""; elif ((CUR_BAT <= 20)) then BAT_ICON=""; fi

		notify-send --urgency=critical "$BAT_ICON $CUR_BAT%: Low Battery!" -r 2
	fi

	PREV_BAT_STAT=$(cat /sys/class/power_supply/BAT*/status)
done
