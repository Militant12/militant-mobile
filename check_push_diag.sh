#!/usr/bin/env bash

set -u

PKG="${1:-com.militant.militant_flutter}"
ADB_BIN="${ADB_BIN:-adb}"
BASE_URL="${BASE_URL:-}"
API_TOKEN="${API_TOKEN:-}"
API_PATH="${API_PATH:-/v1/notifications.php?action=test}"
LOG_FILE="${LOG_FILE:-/var/log/apache2/error.log}"

print_section() {
  echo
  echo "=== $1 ==="
}

echo "Diagnostic push pour: $PKG"

print_section "ADB / Appareil"
if ! command -v "$ADB_BIN" >/dev/null 2>&1; then
  echo "adb introuvable."
  ADB_OK=0
else
  ADB_OK=1
fi

if [ "$ADB_OK" -eq 1 ]; then
  DEVICES="$("$ADB_BIN" devices | awk 'NR>1 && $2=="device" {print $1}')"
  if [ -z "$DEVICES" ]; then
    echo "Aucun appareil Android connecté."
  else
    echo "Appareil(s) connecté(s):"
    echo "$DEVICES"
    SERIAL="$(echo "$DEVICES" | head -n 1)"
    ADB=("$ADB_BIN" -s "$SERIAL")

    print_section "Permission notifications"
    "${ADB[@]}" shell appops get "$PKG" POST_NOTIFICATION 2>/dev/null \
      || "${ADB[@]}" shell cmd appops get "$PKG" POST_NOTIFICATION 2>/dev/null \
      || echo "Impossible de lire appops."

    print_section "Canaux / blocages (snapshot)"
    "${ADB[@]}" shell dumpsys notification --noredact 2>/dev/null \
      | grep -iE "$PKG|messages|calls|blocked|importance" \
      | head -n 120 \
      || echo "Aucune info canal trouvée (ou accès limité)."
  fi
fi

print_section "Test API / notification test"
if [ -n "$BASE_URL" ] && [ -n "$API_TOKEN" ]; then
  URL="${BASE_URL%/}${API_PATH}"
  echo "POST $URL"
  curl -sS -X POST "$URL" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{}' \
    || echo "Echec requête API."
else
  echo "BASE_URL ou API_TOKEN non défini -> test API ignoré."
  echo "Exemple:"
  echo "BASE_URL=\"https://ton-domaine/api\" API_TOKEN=\"token\" ./check_push_diag.sh"
fi

print_section "Logs serveur OneSignal (snapshot)"
if [ -r "$LOG_FILE" ]; then
  MATCHES="$(tail -n 300 "$LOG_FILE" | grep -iE "OneSignal|push|Group message push error|Messages API error" || true)"
  if [ -n "$MATCHES" ]; then
    echo "$MATCHES" | tail -n 40
  else
    echo "Aucune erreur OneSignal/push trouvée dans les 300 dernières lignes."
  fi
else
  echo "Log non lisible: $LOG_FILE"
  echo "Tu peux tester avec: sudo tail -f $LOG_FILE"
fi

echo
echo "Diagnostic terminé."
