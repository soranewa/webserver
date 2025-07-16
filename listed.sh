#!/bin/bash
trap "exit" INT TERM ERR
trap "kill 0" EXIT

# Warna ANSI
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
WHITE="\033[1;37m"
NC="\033[0m" # No Color

IP_LOCAL=$(hostname -I | awk '{print $1}')

# Fungsi untuk mengecek WordPress
is_wordpress() {
    local root=$1
    [[ -f "$root/wp-config.php" || -f "$root/public/wp-config.php" ]]
}

echo -e "${CYAN}===============================================================================${NC}"
printf "${CYAN}%-3s %-12s %-30s %-30s %-10s${NC}\n" "NO" "FOLDER" "DOMAIN" "URL" "STATUS"
echo -e "${CYAN}-------------------------------------------------------------------------------${NC}"

i=1
for conf in /etc/nginx/sites-available/{web,wp,app,site}*; do
    [[ -f "$conf" ]] || continue
    PORT=$(basename "$conf" | cut -d'_' -f2)
    ROOT=$(grep 'root ' "$conf" | awk '{print $2}' | sed 's/;//')
    FOLDER=$(basename "$ROOT")
    [[ -z "$FOLDER" || -z "$PORT" ]] && continue
    
    # Cek apakah WordPress
    WP_CHECK=""
    if is_wordpress "$ROOT"; then
        WP_CHECK=" (WP)"
    fi
    
    if [[ -f "$ROOT/.domain" ]]; then
        DOMAIN=$(cat "$ROOT/.domain")
        URL="http://${IP_LOCAL}:${PORT}"
        STATUS="${GREEN}public${NC}"
        printf "%-3s %-12s %-30s %-30s %-10b\n" "$i" "${FOLDER}${WP_CHECK}" "$DOMAIN" "$URL" "$STATUS"
    else
        DOMAIN="-"
        URL="http://${IP_LOCAL}:${PORT}"
        STATUS="${YELLOW}local${NC}"
        printf "%-3s %-12s %-30s %-30s %-10b\n" "$i" "${FOLDER}${WP_CHECK}" "$DOMAIN" "$URL" "$STATUS"
    fi
    ((i++))
done

echo -e "${CYAN}===============================================================================${NC}"
