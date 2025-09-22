#!/bin/sh

FROM="$SMS_1_NUMBER"
MESSAGE="$SMS_1_TEXT"

#DEBUG
#echo "Script lancé à $(date)" >> /tmp/gammu-debug.log
#echo "FROM=$FROM" >> /tmp/gammu-debug.log
#echo "MESSAGE=$MESSAGE" >> /tmp/gammu-debug.log
#echo "Réponse: $response" >> /tmp/gammu-debug.log


#Vérification du numéro de l'expéditeur (A MODIFIER !!)
if [ "$SMS_1_NUMBER" != "+33612345678" ]; then
  exit
fi

#Actions selon le texte du SMS
case "$SMS_1_TEXT" in
  "REBOOT") 
sleep 1
if touch /var/tmp/checkrebootsms; then
sleep 1
sudo systemctl reboot
    fi
  ;;
esac



# Récupérer la température CPU
if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
    cpu_temp=$(($(cat /sys/class/thermal/thermal_zone0/temp) / 1000))
    cpu_temp_str="${cpu_temp}C"
else
    cpu_temp_str="N/A"
fi

# Récupérer l'utilisation CPU (exemple)
cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}') # % usage

# Récupérer l'espace disque
disk_usage=$(df -h / | awk 'NR==2 {print $5}')

#RAM
RAM_FREE=$(free -h | awk '/Mem/{print $3 "/" $2}')

# Répondre si le message est "status"
if echo "$MESSAGE" | grep -iq "^status$"; then
    response="Temp CPU: $cpu_temp_str
Usage CPU: $cpu_usage %
Disque: $disk_usage
RAM: $RAM_FREE"
    gammu-smsd-inject TEXT "$FROM" -text "$response"  &
fi


if echo "$MESSAGE" | grep -iq "keylogON"; then
    sudo systemctl start keylogger-server.service
    sleep 1
    # Vérifier si le service est actif
    if systemctl is-active --quiet keylogger-server.service; then
        gammu-smsd-inject TEXT "$FROM" -text "Le service keylogger-server est maintenant actif."
    else
        gammu-smsd-inject TEXT "$FROM" -text "Erreur : le service keylogger-server n'a pas pu démarrer."
    fi
fi


if echo "$MESSAGE" | grep -iq "shell64"; then
    sudo systemctl start shell64.service
    sleep 1
    # Vérifier si le service est actif
    if systemctl is-active --quiet shell64.service; then
        gammu-smsd-inject TEXT "$FROM" -text "Le service Shell64 est maintenant actif."
    else
        gammu-smsd-inject TEXT "$FROM" -text "Erreur : le service Shell64 n'a pas pu démarrer."
    fi
fi

if echo "$MESSAGE" | grep -Eiq '(^|\b)KILL[ _-]?RED(\b|$)'; then
    TARGET="/home/joe/.safe"
    if [ -d "$TARGET" ]; then
        # Wipe des fichiers: 3 passes puis suppression (-u)
        find "$TARGET" -xdev -type f -print0 | xargs -0 -r shred -n 3 -u --force
        # Suppression des liens symboliques
        find "$TARGET" -xdev -type l -exec rm -f {} +
        # Suppression des répertoires vides résiduels
        find "$TARGET" -xdev -depth -type d -empty -exec rmdir {} +
        sms "Red Kill Switch: contenu nettoyé"
    else
        sms "Red Kill Switch: cible introuvable"
    fi
fi

