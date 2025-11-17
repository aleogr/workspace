#!/bin/bash

apt install sudo -y
echo "aleogr ALL=(ALL) ALL" > "/etc/sudoers.d/aleogr"
chmod 0440 "/etc/sudoers.d/aleogr"

apt install libpam-u2f libpam-pwquality -y

LINE_TO_ADD_U2F="auth sufficient pam_u2f.so cue nouserok authfile=/etc/Yubico/u2f_mappings [cue_prompt=Tap your security key]"
FILE_TO_MODIFY_AUTH="/etc/pam.d/common-auth"
BACKUP_SUFFIX=".bak_security_sh"
sed -i"$BACKUP_SUFFIX" "1i $LINE_TO_ADD_U2F" "$FILE_TO_MODIFY_AUTH"

LINE_TO_ADD_PW="password requisite pam_pwquality.so retry=3 minlen=12 difok=4 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1 enforce_for_root"
FILE_TO_MODIFY_PW="/etc/pam.d/common-password"
sed -i"$BACKUP_SUFFIX" "1i $LINE_TO_ADD_PW" "$FILE_TO_MODIFY_PW"