#!/bin/bash
# Service unique: teste la connectivité chaque minute; exécute une action seulement si KO.

URL="http://www.gstatic.com/generate_204"   # 204 attendu si Internet OK
TIMEOUT=5
RETRIES=2          # 2 tentatives par cycle
DELAY_RETRY=2      # pause entre tentatives
SLEEP_BETWEEN=60   # attendre 60 s entre deux cycles
ALERT_CMD="/usr/local/bin/sms 'Alert server ! Connection KO !'"

while true; do
  ok=0
  for ((i=1; i<=RETRIES; i++)); do
    status=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" "$URL")
    if [[ $? -eq 0 && "$status" == "204" ]]; then
      ok=1
      break
    fi
    [[ $i -lt $RETRIES ]] && sleep "$DELAY_RETRY"
  done

  if [[ $ok -eq 0 ]]; then
    eval "$ALERT_CMD"
  fi

  sleep "$SLEEP_BETWEEN"
done
