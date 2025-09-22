#!/bin/bash

while true; do
  echo "En attente de connexion sur le port 9999..."
  
  # Lire connexion unique et gérer un fichier
  nc -l -p 9999 | (
    FILE_OUT=""
    while IFS= read -r line; do
      if echo "$line" | grep -q '^<<FILE_START:.*>>$'; then
        FILE_OUT=$(echo "$line" | sed -E 's/^<<FILE_START:(.*)>>$/\1/')
        echo "Réception fichier $FILE_OUT..."
        > "$FILE_OUT"
      elif echo "$line" | grep -q '^<<FILE_END>>$'; then
        echo "Fichier $FILE_OUT reconstitué."
        # Fin du fichier => sortie boucle lecture (casse sous-shell, ferme connexion)
        break
      elif [ -n "$FILE_OUT" ]; then
        echo "$line" | base64 -d >> "$FILE_OUT"
      fi
    done
  )
done
