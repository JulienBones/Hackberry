#!/bin/bash

SERVER_IP="127.0.0.1"
PORT=9999

for FILE in "$@"; do
  if [ ! -f "$FILE" ]; then
    echo "Fichier $FILE introuvable."
    continue
  fi
  echo "Envoi du fichier $FILE..."

  {
    echo "<<FILE_START:$(basename "$FILE")>>"
    base64 "$FILE"
    echo "<<FILE_END>>"
    echo "<<FIN>>"
  } | proxychains nc "$SERVER_IP" "$PORT" &

 # On attend un peu, puis on tue nc pour forcer fermeture propre, remplacer 5 par le temps adapté
  sleep 5
  pkill -f "nc $SERVER_IP $PORT"

  echo "Fichier $FILE envoyé (connexion close forcée)."
done
