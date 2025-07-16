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

# Fungsi untuk mengecek apakah instance WordPress
is_wordpress() {
    local root=$1
    [[ -f "$root/wp-config.php" || -f "$root/public/wp-config.php" ]]
}

echo -e "${CYAN}----------------[ Website Instances ]-----------------${NC}"

# Daftar semua website instance terlebih dahulu
ALL_LIST=""
for conf in /etc/nginx/sites-available/{web,wp,app,site}*; do
    [ -e "$conf" ] || continue
    PORT=$(basename "$conf" | cut -d'_' -f2)
    ROOT=$(grep "root " "$conf" | head -n1 | awk '{print $2}' | sed 's/;//')
    FOLDER=$(basename "$ROOT")
    DOMAIN_FILE="$ROOT/.domain"

    if [[ -f "$DOMAIN_FILE" ]]; then
        DOMAIN=$(cat "$DOMAIN_FILE")
        LINK="https://$DOMAIN"
    else
        LINK="http://${IP_LOCAL}:${PORT}"
    fi
    ALL_LIST+="${WHITE}${FOLDER}${NC} → ${CYAN}${LINK}${NC}\n"
done

echo -e "$ALL_LIST"

# Khusus untuk WordPress instance
echo -e "\n${CYAN}📋 Menjalankan List WordPress Instance...${NC}"
echo -e "${CYAN}📋 Daftar WordPress Instance yang Terinstal:${NC}"
echo -e "${CYAN}===============================================================================${NC}"
printf "${CYAN}%-3s %-12s %-30s %-30s %-10s${NC}\n" "NO" "FOLDER" "DOMAIN" "URL" "STATUS"
echo -e "${CYAN}-------------------------------------------------------------------------------${NC}"

i=1
WP_LIST=""
for conf in /etc/nginx/sites-available/{web,wp}_*; do
    [ -e "$conf" ] || continue
    PORT=$(basename "$conf" | cut -d'_' -f2)
    ROOT=$(grep "root " "$conf" | head -n1 | awk '{print $2}' | sed 's/;//')
    FOLDER=$(basename "$ROOT")
    DOMAIN_FILE="$ROOT/.domain"

    if is_wordpress "$ROOT"; then
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
        WP_LIST+="${WHITE}${FOLDER}${NC} → ${CYAN}${LINK}${NC}\n"
        ((i++))
    fi
done

echo -e "${CYAN}===============================================================================${NC}"

if [ $i -eq 1 ]; then
    echo -e "${YELLOW}Tidak ada WordPress instance yang terdeteksi${NC}"
else
    echo -e "\n${CYAN}🌐 Daftar Link Akses Cepat WordPress:${NC}"
    echo -e "$WP_LIST"
fi
