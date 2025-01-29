#!/usr/bin/env bash

# vish - visual editor in bash
# Copyright (c) 2024 Ian P. Jarvis

set -o vi

gfile="$@"

bind 'set blink-matching-paren ON'
bind 'set horizontal-scroll-mode OFF'
bind -m vi-insert '"\e[A":previous-screen-line'
bind -m vi-insert '"\e[B":next-screen-line'
bind -m vi-move '"k":previous-scren-line'
bind -m vi-move '"j":next-screen-line'
bind -m vi-move '"o":i\n'
bind -m vi-move '"O":I\n'
bind -m vi-move -x '"gQ":exsh "$gfile" && exit 0'
bind -m vi-insert '"\n":self-insert'
bind -m vi-insert '"\r":\n'
bind -m vi-insert '"\t":tab-insert'

if [[ -n "$gfile" && -e "$gfile" ]]; then insert_text=$(<"$gfile"); else insert_text=""; fi

IFS=
read -er -d $'\04' -i "$insert_text" gettext

bind -m vi-insert '"\n":accept-line'

if [[ -z "$gfile" ]]; then read -er -p "Save as: " gfile; fi

if [[ -n "$gfile" ]] then echo "$gettext" > "$gfile"; fi
