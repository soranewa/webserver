#!/bin/bash

echo "📋 Daftar WordPress Instance yang Terinstal:"
echo "==============================================="
printf "%-20s %-10s %-30s %-10s\n" "FOLDER" "PORT" "DOMAIN" "STATUS"
echo "-----------------------------------------------"

for conf in /etc/nginx/sites-available/wp_*; do
  [ -e "$conf" ] || continue  # skip jika tidak ada
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
    printf "%-20s %-10s %-30s %-10s\n" "$FOLDER" "$PORT" "$DOMAIN" "$STATUS"
  fi
done

echo "==============================================="
