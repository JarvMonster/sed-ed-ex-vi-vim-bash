#!/usr/bin/env bash

# edsh - line editor with sed in bash
# Copyright (c) 2024 Ian P. Jarvis

gfile="$@"

shopt -s extglob

unsaved_work=0

if [[ -n "$gfile" ]]; then gbuffer=$(<"$gfile"); else gbuffer=""; fi

undo_buffer=""
cut_buffer=""

address="1"
undo_address="1"

if [[ "$(basename $0)" == "edsh" ]]; then prompt="*"; else prompt=":"; fi

while [[ 1 -gt 0 ]]; do

  read -er -p "$prompt" gcmd

  case "$gcmd" in

    # append/insert lines of text
    *([:digit:])[ai])
      undo_address="$address"
      undo_buffer="$gbuffer"
      address=$(echo "$gcmd" | sed 's/[ai]//')
      if [[ -z "$address" ]]; then address="$undo_address"; fi
      glines=""
      gline=""
      i=0
      read -er gline
      while [[ "$gline" != '.' ]]; do
        glines="$glines$gline\n"
        i+=1
        read -er gline
      done
      gbuffer=$(echo "$gbuffer" | sed "$gcmd $glines")
      address=$(("$address" + "$i"))
      unsaved_work=1
      ;;

    # change lines of text
    *([:digit:])?(,)*([:digit:])c)
      undo_address="$address"
      undo_buffer="$gbuffer"
      address=$(echo "$gcmd" | sed 's/c//' | sed 's/,[[:digit:]]*//')
      end_address=$(echo "$gcmd" | sed 's/c//' | sed 's/[[:digit:]]*,//')
      if [[ -z "$address" ]]; then address="$undo_address"; fi
      if [[ -z "$end_address" ]]; then end_address="$address"; fi
      glines=""
      gline=""
      i=0
      read -er gline
      while [[ "$gline" != '.' ]]; do
        glines="$glines$gline\n"
        i+=1
        read -er gline
      done
      cut_buffer=$(echo "$gbuffer" | sed -n "$address,$end_address"'p')
      gbuffer=$(echo "$gbuffer" | sed "$gcmd $glines")
      address=$(("$address" + "$i"))
      unsaved_work=1
      ;;

    # delete lines of text, and put in cut buffer
    *([:digit:])?(,)*([:digit:])d)
      undo_address="$address"
      undo_buffer="$gbuffer"
      address=$(echo "$gcmd" | sed 's/d//' | sed 's/,[[:digit:]]*//')
      end_address=$(echo "$gcmd" | sed 's/d//' | sed 's/[[:digit:]]*,//')
      if [[ -z "$address" ]]; then address="$undo_address"; fi
      if [[ -z "$end_address" ]]; then end_address="$address"; fi
      cut_buffer=$(echo "$gbuffer" | sed -n "$address,$end_addresss"'p')
      gbuffer=$(echo "$gbuffer" | sed "$gcmd")
      unsaved_work=1
      ;;

    # edit file, into buffer
    [eE]*([:space:])*([:graph:]))
      tmp_gfile="$gfile"
      gfile=$(echo "$gcmd" | sed 's/[eE][[:space:]]*//')
      if [[ -z "$gfile" ]]; then gfile="$tmp_gfile"; fi
      if [[ -n "$gfile" ]]; then
        gbuffer=$(<"$gfile")
        unsaved_work=0
      else
        echo "? no default filename"
      fi
      ;;

    f*([:space:])*([:graph:]))
      gfile=$(echo "$gcmd" | sed 's/f[[:space:]]*//')
      if [[ -z "$gfile" ]]; then
        echo "? no filename"
      else
        unsaved_work=1
      fi
      ;;

    # regular expressions
    *([:digit:])?(,)*([:digit])[gGs]/*)
      undo_buffer="$gbuffer"
      if [[ "${gcmd:0:1}" =~ !([:digit:]) && "${gcmd:0:1}" == "s" ]]; then
        gbuffer=$(echo "$gbuffer" | sed "$address$gcmd")
      else
        gbuffer=$(echo "$gbuffer" | sed "$gcmd")
      fi
      unsaved_work=1
      ;;

    # join text into one line, place into cut buffer
    *([:digit:])?(,)*([:digit:])j)
      undo_address="$address"
      undo_buffer="$gbuffer"
      address=$(echo "$gcmd" | sed 's/j//g' | sed 's/,[[:digit:]]*//g')
      end_address=$(echo "$gcmd" | sed 's/j//g' | sed 's/[[:digit:]]*,//g')
      if [[ -z "$address" ]]; then address="$undo_address"; fi
      if [[ -z "$end_address" ]]; then end_address=$(("$address" + 1)); fi
      cut_buffer=$(echo "$gbuffer" | sed -n "$address,$end_address"'p' | sed 's/\n//g')
      gbuffer=$(echo "$gbuffer" | sed "$address,$end_address"'d')
      glines=$(echo "$cut_buffer" | sed 's/\n//g')
      gbuffer=$(echo "$gbuffer" | sed "$address"'i '"$glines")
      unsaved_work=1
      ;;

    # list buffer lines
    *([:digit:])?(,)*([:digit:])l)
      address=$(echo "$gcmd" | sed 's/l//' | sed 's/,[[:digit:]]*//')
      end_address=$(echo "$gcmd" | sed 's/l//' | sed 's/[[:digit:]]*,//')
      if [[ -z "$address" ]]; then address="$undo_address"; fi
      if [[ -z "$end_address" ]]; then end_address="$address"; fi
      echo "$gbuffer" | sed -n "gcmd"
      address="$end_address"
      ;;

    # move/transfer lines of text
    *([:digit:])?(,)*([:digit:])[mt]+([:digit:]))
      undo_address="$address"
      undo_buffer="$gbuffer"
      address=$(echo "$gcmd" | sed 's/[mt][[:digit:]]+//' | sed 's/,[[:digit:]]*//')
      end_address=$(echo "$gcmd" | sed 's/[mt][[:digit:]]+//' | sed 's/[[:digit:]]*,//')
      if [[ -z "$address" ]]; then address="$undo_address"; fi
      if [[ -z "$end_address" ]]; then end_address="$address"; fi
      move_lines=$(echo "$gbuffer" | sed -n "$address,$end_address"'p')
      move_address=$(echo "$gcmd" | sed 's/[[:digit:]]*,\?[[:digit:]]*[mt]//')
      if [[ $(("$move_address" <= "$address")) ]]; then
        gbuffer=$(echo "$gbuffer" | sed "$address,$address_end"'d')
        gbuffer=$(echo "$gbuffer" | sed "$move_address"'i '"$move_lines")
        address="$move_address"
        unsaved_work=1
      elif [[ $(("$move_address" >= "$end_address")) ]]; then
        gbuffer=$(echo "$gbuffer" | sed "$move_address"'i '"$move_lines")
        gbuffer=$(echo "$gbuffer" | sed "$address,$end_address"'d')
        address="$move_address"
        unsaved_work=1
      else
        echo "? move address within text to move"
      fi
      ;;

    # numbered line print
    *([:digit:])?(,)*([:digit:])n)
      address=$(echo "$gcmd" | sed 's/n//' | sed 's/,[[:digit:]]*//')
      end_address=$(echo "$gcmd" | sed 's/n//' | sed 's/[[:digit:]]*,//')
      if [[ -z "$address" ]]; then address="$undo_address"; fi
      if [[ -z "$end_address" ]]; then end_address="$address"; fi
      ####echo "$gbuffer" | awk 'NR >= $address && NR <= $end_address {print NR"\t"$0}'
      echo "$gbuffer" | sed -n "$address,$end_address"'='";$address,$end_address"'p'";"
      address="$end_address"
      ;;

    # print lines
    *([:digit:])?(,)*([:digit:])p)
      address=$(echo "$gcmd" | sed 's/p//' | sed 's/,[[:digit:]]*//')
      end_address=$(echo "$gcmd" | sed 's/p//' | sed 's/[[:digit:]]*,//')
      if [[ -z "$address" ]]; then address="$undo_address"; fi
      if [[ -z "$end_address" ]]; then end_address="$address"; fi
      echo "$gbuffer" | sed -n "$gcmd"
      address="$end_address"
      ;;

    # prompt string
    P*)
      prompt="${gcmd:1:${#gcmd} - 1}"
      ;;

    # quit, with warning
    q)
      if [[ unsaved_work ]]; then
        echo "? unsaved work"
      else
        exit 0
      fi
      ;;

    # quit, WITHOUT warning
    Q | q!)
      exit 0
      ;;

    # read in file and append contents
    *([:digit:])r+([:space:])+([:graph:]))
      undo_address="$address"
      undo_buffer="$gbuffer"
      address=$(echo "$gcmd" | sed 's/r[[:space:]]*[[:graph:]]*//')
      if [[ -z "$address" ]]; then address="$undo_address"; fi
      gbuffer=$(echo "$gbuffer" | sed "$gcmd")
      unsaved_work=1
      ;;

    # undo
    u)
      address="$undo_address"
      gbuffer="$undo_buffer"
      ;;

    # write to file
    *([:digit:])?(,)*([:digit:])w*([:space:])*)
      tmp_gfile="$gfile"
      gfile=$(echo "$gcmd" | sed 's/[[:digit:]]*,\?[[:digit:]]*w[[:space:]]*//')
      if [[ -z "$gfile" ]]; then gfile="$tmp_gfile"; fi
      if [[ -n "$gfile" ]]; then
        echo "$gbuffer" | sed -n "$gcmd"
        unsaved_work=0
      else
        echo "? no filename"
      fi
      ;;

    # write to file and then quit
    *([:digit:])?(,)*([:digit:])wq)
      tmp_gfile="$gfile"
      gfile=$(echo "$gcmd" | sed 's/[[:digit:]]*,\?[[:digit:]]*wq[[:space:]]*//')
      if [[ -z "$gfile" ]]; then gfile="$tmp_gfile"; fi
      if [[ -n "$gfile" ]]; then
        echo "$gbuffer" | sed -n "${gcmd:0:-1} $gfile"
        unsaved_work=0
        exit 0
      else
        echo "? no filename"
      fi
      ;;

    # append lines to file
    *([:digit:])?(,)*([:digit:])W*([:space:])*)
      tmp_gfile="$gfile"
      gfile=$(echo "$gcmd" | sed 's/[[:digit:]]*,\?[[:digit:]]*W[[:space:]]*//')
      if [[ -z "$gfile" ]]; then gfile="$tmp_gfile"; fi
      if [[ -n "$gfile" ]]; then
        addr_space=$(echo "$gcmd" | sed 's/W[[:space:]]*[[:graph:]]*//')
        echo "$gbuffer" | sed -n "$addr_space"'p' >> "$gfile"
        unsaved_work=0
      else
        echo "? no filename"
      fi
      ;;

    # paste lines from cut buffer into buffer
    *([:digit:])x)
      undo_address="$address"
      undo_buffer="$gbuffer"
      address=$(echo "$gcmd" | sed 's/x//')
      if [[ -z "$address" ]]; then address="$undo_address"; fi
      gbuffer=$(echo "$gbuffer" | sed "$address"'i '"$cut_buffer")
      unsaved_work=1
      ;;

    # yank lines from buffer
    *([:digit:])?(,)*([:digit:])y)
      undo_address="$address"
      undo_buffer="$gbuffer"
      address=$(echo "$gcmd" | sed 's/y//' | sed 's/,[[:digit:]]*//')
      end_address=$(echo "$gcmd" | sed 's/y//' | sed 's/[[:digit:]]*,//')
      if [[ -z "$address" ]]; then address="$undo_address"; fi
      if [[ -z "$end_address" ]]; then end_address="$address"; fi
      cut_buffer=$(echo "$gbuffer" | sed -n "$address,$end_address"'p')
      gbuffer=$(echo "$gbuffer" | sed "$address,$end_address"'d')
      address="$end_address"
      unsaved_work=1
      ;;

    # scroll print/view
    *([:digit:])z)
      echo "$gbuffer" | less -FX
      ;;

    # shell command
    !*)
      "${gcmd:1:${#gcmd} - 1}"
      ;;

    # print line number of addressed line or total lines
    ?($)=)
      if [[ "${gcmd:0:1}" == "$" ]]; then
        echo "$gbuffer" | wc -l
      else
        echo "$address"
      fi
      ;;

    # print addressed line number specified
    *([:digit:]))
      undo_address="$address"
      address="$gcmd"
      echo "$gbuffer" | sed -n "$address"'p'
      ;;

    # print next line
    '')
      undo_adddress="$address"
      address=$(("$address" + 1))
      echo "$gbuffer" | sed -n "$address"'p'
      ;;

    # otherwise all other commands not recognized
    *)
      echo "? command not recognized"
      ;;

  esac

done
