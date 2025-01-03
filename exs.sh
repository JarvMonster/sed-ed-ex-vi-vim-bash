#!/usr/bin/env bash

# exsh - extended line editor with sed in bash
# Copyright (c) 2024 Ian P. Jarvis

printf "\e[?1049h" # enable alt screen buffer
LINES=$(tput lines)
printf "\e[$(($LINES - 1));0H" # move cursor to bottom

edsh "$@"

printf "\e[?1049l" # disable alt screen buffer
