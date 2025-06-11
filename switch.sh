#!/bin/bash

# === Root Check ===
if [[ $EUID -ne 0 ]]; then
  echo "Script harus dijalankan sebagai root"
  exit 1
fi

# === Input ===
read -rp "📁 Masukkan nama folder instalasi WordPress di /var/www (contoh:blog): " WP_FOLDER
WP_DIR="/var/www/$WP_FOLDER"
WP_CONFIG="$WP_DIR/wp-config.php"

if [[ ! -f "$WP_CONFIG" ]]; then
  echo "❌ wp-config.php tidak ditemukan di $WP_DIR"
  exit 1
fi

# === Ambil info DB dari wp-config.php ===
DB_NAME=$(grep DB_NAME "$WP_CONFIG" | cut -d "'" -f 4)
DB_USER=$(grep DB_USER "$WP_CONFIG" | cut -d "'" -f 4)
DB_PASS=$(grep DB_PASSWORD "$WP_CONFIG" | cut -d "'" -f 4)

if [[ -z "$DB_NAME" || -z "$DB_USER" || -z "$DB_PASS" ]]; then
  echo "❌ Gagal baca info database dari wp-config.php"
  exit 1
fi

# === Pilih mode sinkronisasi ===
echo "🔁 Pilih target sinkronisasi akses WordPress:"
echo "1. Sinkronisasi ke IP lokal + port"
echo "2. Sinkronisasi ke domain publik (Cloudflare)"
read -rp "Pilih (1/2): " MODE

if [[ "$MODE" == "1" ]]; then
    IP_LAN=$(hostname -I | awk '{print $1}')
    read -rp "Masukkan port WordPress instance (contoh: 8000): " PORT
    URL="http://${IP_LAN}:${PORT}"
elif [[ "$MODE" == "2" ]]; then
    read -rp "Masukkan domain publik (contoh: sub.domain.com): " TARGET
    URL="https://$TARGET"
    echo "$TARGET" > "$WP_DIR/.domain"

else
    echo "❌ Input tidak valid"
    exit 1
fi


# === Update ke database ===
echo "🛠️ Menyetel siteurl dan home di database WordPress ke: $URL"
mysql -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "
UPDATE wp_options SET option_value = '$URL' WHERE option_name = 'siteurl';
UPDATE wp_options SET option_value = '$URL' WHERE option_name = 'home';
"

echo "✅ Sinkronisasi selesai. Sekarang WordPress akan diarahkan ke: $URL"
