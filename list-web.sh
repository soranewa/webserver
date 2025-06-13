#!/bin/bash

echo "📋 Daftar WordPress Instance yang Terinstal:"
echo "=============================================================="
printf "%-3s %-15s %-6s %-35s %-10s\n" "NO" "FOLDER" "PORT" "DOMAIN" "STATUS"
echo "--------------------------------------------------------------"

i=1
for conf in /etc/nginx/sites-available/wp_*; do
  [ -e "$conf" ] || continue
  PORT=$(basename "$conf" | cut -d'_' -f2)
  ROOT=$(grep "root " "$conf" | head -n1 | awk '{print $2}' | sed 's/;//')
  FOLDER=$(basename "$ROOT")
  DOMAIN_FILE="$ROOT/.domain"

  if [[ -f "$ROOT/wp-config.php" ]]; then
    if [[ -f "$DOMAIN_FILE" ]]; then
      DOMAIN=$(cat "$DOMAIN_FILE")
      STATUS="public"
    else
      DOMAIN="-"
      STATUS="local only"
    fi
    printf "%-3s %-15s %-6s %-35s %-10s\n" "$i" "$FOLDER" "$PORT" "$DOMAIN" "$STATUS"
    ((i++))
  fi
done

echo "=============================================================="
