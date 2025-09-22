#!/bin/bash
### Dépendences : python3-geoip2 python3-plotly python3-pandas python3-folium
### ADAPTER LES CHEMINS !!!
LOG_FILE="/var/log/sshesame/sshd-honeypot.log"
DICO_FILE="/home/joe/honeypot/pass.txt"
USERS_FILE="/home/joe/honeypot/users.txt"
TMP_MDP="tmp_mdp.txt"
TMP_USERS="tmp_users.txt"

mkdir -p /home/joe/honeypot/
clear && bash /etc/update-motd.d/00-header-priv
echo "Extration des data du honeypot.. "
# Extraire les mots de passe et suppr lignes vides
grep 'with password' "$LOG_FILE" | sed -n 's/.*with password "\([^"]*\)".*/\1/p' | sed '/^[[:space:]]*$/d' > "$TMP_MDP"

# Extraire les utilisateurs et suppr lignes vides
grep 'authentication for user' "$LOG_FILE" | sed -n 's/.*user "\([^"]*\)".*/\1/p' | sed '/^[[:space:]]*$/d' > "$TMP_USERS"

# Mettre à jour le dico sans doublons
cat "$DICO_FILE" "$TMP_MDP" 2>/dev/null | sort -u > "${DICO_FILE}.new"
mv "${DICO_FILE}.new" "$DICO_FILE"

# Mettre à jour la liste user sans doublons
cat "$USERS_FILE" "$TMP_USERS" 2>/dev/null | sort -u > "${USERS_FILE}.new"
mv "${USERS_FILE}.new" "$USERS_FILE"
sleep 0.5
# Après extraction (avant rm des temporaires)
# Normaliser fin de ligne et espaces pour éviter des doublons “fantômes”
tr -d '\r' < "$TMP_USERS" | sed 's/[[:space:]]\+$//' | sort | uniq -c | sort -nr | head -10 \
  | awk '{c=$1; $1=""; sub(/^ +/,""); print $0 "," c}' > /home/joe/honeypot/topuser.csv

tr -d '\r' < "$TMP_MDP" | sed 's/[[:space:]]\+$//' | sort | uniq -c | sort -nr | head -10 \
  | awk '{c=$1; $1=""; sub(/^ +/,""); print $0 "," c}' > /home/joe/honeypot/toppass.csv
sleep 0.5
# Supprimer fichiers temporaires
rm "$TMP_MDP" "$TMP_USERS"
sleep 1.5
grep -oP '\[\K[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' /var/log/sshesame/sshd-honeypot.log | sort | uniq -c | sort -nr > /home/joe/honeypot/ip.txt
#sort /home/joe/honeypot/users.txt | uniq -c | sort -nr | head -10 | awk '{c=$1; $1=""; sub(/^ /,""); printf "%s,%s\n",$0,c}' > /home/joe/honeypot/topuser.csv
#sort /home/joe/honeypot/pass.txt  | uniq -c | sort -nr | head -10 | awk '{c=$1; $1=""; sub(/^ /,""); printf "%s,%s\n",$0,c}' > /home/joe/honeypot/toppass.csv
echo "Extraction terminé ! :)"
sleep 1.5
echo "Cartographie des attaquants"
python3 /home/joe/honeypot/map/map.py > /dev/null
echo "Cartographie terminé ! :)"
sleep 1
awk 'length($0) >= 8' /home/joe/honeypot/pass.txt > /home/joe/honeypot/wifi.txt

