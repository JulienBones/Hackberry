#!/bin/bash

KEYLOGS="~/keylogger/keylogs.txt"
ARCHIVE="~/keylogger/logs/all_keylogs.txt"

# Crée le dossier logs s'il n'existe pas
mkdir -p ~/keylogger/logs

# Ajoute le contenu de keylogs.txt à l'archive (s'il existe et n'est pas vide)
if [ -s "$KEYLOGS" ]; then
    cat "$KEYLOGS" >> "$ARCHIVE"
    echo -e "\n--- Nouvelle session ---\n" >> "$ARCHIVE"
    > "$KEYLOGS"  # Vide le fichier
fi
