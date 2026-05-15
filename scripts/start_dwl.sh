#!/bin/bash

# Everything has to be in this block otherwise DWL startup is slow
{
	$HOME/.config/scripts/wallpaper_dwl.sh &
	$HOME/.config/scripts/batbluemon.sh &
} &

exit 0

