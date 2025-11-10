#!/bin/bash

mkdir -p /etc/Yubico && cd /etc/Yubico
C=1
U="${1:-$USER}"
while true; do
	TMP_FILE="key${C}.tmp"
	read -p "Insert YubiKey and press [enter]"
	pamu2fcfg -n >> "$TMP_FILE"
	read -p "Remove Yubikey and press [enter]"
	read -p "Another key (Y/n)? " R
	case "$R" in
		[yY] | [yY][eE][sS] )
			C=$((C + 1))
			continue
			;;
		* )
			break
			;;
	esac
done
{ printf "$U"; cat key*.tmp | tr -d '\n\r'; echo; echo; } >> u2f_mappings
rm key*.tmp