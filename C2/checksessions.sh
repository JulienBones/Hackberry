#!/bin/bash

# Fichier pour stocker le nombre de sessions précédentes
STATE_FILE="/tmp/msf_sessions_count"
TMUX_SESSION="msf"
SMS_NUMBER="+336XXXXXXXX"
GAMMU_CMD="/usr/bin/gammu-smsd-inject"

# Récupérer le nombre de sessions actives
get_session_count() {
  tmux send-keys -t "$TMUX_SESSION" "sessions -l" C-m
  sleep 2
  tmux capture-pane -pt "$TMUX_SESSION" | grep -E 'meterpreter|shell' | wc -l
}

# Initialiser le fichier d'état si besoin
if [ ! -f "$STATE_FILE" ]; then
  echo 0 > "$STATE_FILE"
fi

OLD_COUNT=$(cat "$STATE_FILE")
NEW_COUNT=$(get_session_count)

if [ "$NEW_COUNT" -gt "$OLD_COUNT" ]; then
  $GAMMU_CMD TEXT "$SMS_NUMBER" -text "Nouvelle session Metasploit ouverte !"
fi

echo "$NEW_COUNT" > "$STATE_FILE"
