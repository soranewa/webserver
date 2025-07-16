#!/bin/bash
trap "exit" INT TERM ERR
trap "kill 0" EXIT

IP_LOCAL=$(hostname -I | awk '{print $1}')

# Warna ANSI
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
WHITE="\033[1;37m"
NC="\033[0m" # No Color

echo -e "${CYAN}📋 Daftar WordPress Instance yang Terinstal:${NC}"
echo -e "${CYAN}===============================================================================${NC}"
printf "${CYAN}%-3s %-12s %-30s %-30s %-10s${NC}\n" "NO" "FOLDER" "DOMAIN" "URL" "STATUS"
echo -e "${CYAN}-------------------------------------------------------------------------------${NC}"

i=1
WEB_LIST=""
for conf in /etc/nginx/sites-available/{web,wp}_*; do
  [ -e "$conf" ] || continue
  PORT=$(basename "$conf" | cut -d'_' -f2)
  ROOT=$(grep "root " "$conf" | head -n1 | awk '{print $2}' | sed 's/;//')
  FOLDER=$(basename "$ROOT")
  DOMAIN_FILE="$ROOT/.domain"

  if [[ -f "$ROOT/wp-config.php" || -f "$ROOT/public/wp-config.php" ]]; then
    if [[ -f "$DOMAIN_FILE" ]]; then
      DOMAIN=$(cat "$DOMAIN_FILE")
      STATUS="${GREEN}public${NC}"
      LINK="https://$DOMAIN"
    else
      DOMAIN="-"
      STATUS="${YELLOW}local${NC}"
      LINK="http://${IP_LOCAL}:${PORT}"
    fi

    URL="http://${IP_LOCAL}:${PORT}"
    printf "%-3s %-12s %-30s %-30s %-10b\n" "$i" "$FOLDER" "$DOMAIN" "$URL" "$STATUS"
    WEB_LIST+="${WHITE}${FOLDER}${NC} → ${CYAN}${LINK}${NC}\n"
    ((i++))
  fi
done

echo -e "${CYAN}===============================================================================${NC}"
echo -e "\n${CYAN}🌐 Daftar Link Akses Cepat:${NC}"
echo -e "$WEB_LIST"
