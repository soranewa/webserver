#!/bin/bash

# === Root Check ===
if [[ $EUID -ne 0 ]]; then
  echo "❌ Script harus dijalankan sebagai root"
  exit 1
fi

WEB_ROOT="/var/www"

echo "======================================"
echo "🔁 PILIH MODE AKSES WORDPRESS:"
echo "1. Switch ke LOCAL (IP:PORT)"
echo "2. Switch ke PUBLIC (Domain)"
echo "0. Batal"
echo "======================================"
read -rp "Pilih opsi (0-2): " MODE

if [[ "$MODE" == "0" ]]; then
  echo "❌ Dibatalkan oleh user"
  exit 0
fi

# === Tampilkan list folder WordPress ===
echo ""
echo "📂 Folder WordPress yang tersedia:"
FOLDERS=$(ls -1 "$WEB_ROOT")
PS3="Select Number: "
select WP_FOLDER in $FOLDERS; do
  if [[ -n "$WP_FOLDER" ]]; then
    break
  else
    echo "❌ Pilihan tidak valid."
  fi
done

WP_DIR="$WEB_ROOT/$WP_FOLDER"
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

# === Input berdasarkan mode ===
if [[ "$MODE" == "1" ]]; then
  IP_LAN=$(hostname -I | awk '{print $1}')
  read -rp "Masukkan PORT lokal WordPress instance (contoh: 8000): " PORT
  URL="http://${IP_LAN}:${PORT}"
  rm -f "$WP_DIR/.domain"

elif [[ "$MODE" == "2" ]]; then
  read -rp "Masukkan domain publik (contoh: sub.domain.com): " TARGET
  URL="https://$TARGET"
  echo "$TARGET" > "$WP_DIR/.domain"

else
  echo "❌ Input mode tidak valid."
  exit 1
fi

# === Update ke database WordPress ===
echo "🛠️ Menyetel siteurl dan home di database ke: $URL"
mysql -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "
UPDATE wp_options SET option_value = '$URL' WHERE option_name = 'siteurl';
UPDATE wp_options SET option_value = '$URL' WHERE option_name = 'home';
"

echo "✅ Sinkronisasi selesai. Sekarang WordPress akan diarahkan ke:"
echo "$URL"
