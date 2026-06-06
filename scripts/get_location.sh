#!/bin/bash

# Usage: source get_location.sh "__COUNTRY__" "__CITY__"
# 	where __COUNTRY__ is the two-letter country code (ISO 3166-1 alpha-2)
#
# 	This script does not handle errors (caller's responsibility).

COUNTRY="$1"
CITY="$2"

# Exact match
search_result=$(grep -i "^$CITY,$COUNTRY," ./cities1000_slim.csv | head -n 1)

# If no exact match was found, find the best match
if [[ -z "$search_result" ]]; then
	search_result=$(grep -i ",$COUNTRY," ./cities1000_slim.csv | fzf --filter="$CITY" --delimiter="," --with-nth=1,2 | head -n 1)
fi

IFS=, read -r CITY_MATCH COUNTRY_MATCH LAT LON TIMEZONE <<< "$search_result"

