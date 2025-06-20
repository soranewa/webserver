#!/bin/bash
trap "exit" INT TERM ERR
trap "kill 0" EXIT

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
  echo "👋 Keluar."
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

# === Cari file konfigurasi Nginx berdasarkan WP_DIR ===
NGINX_CONF=""
PORT=""

for file in /etc/nginx/sites-available/wp_*; do
  if grep -q "root $WP_DIR" "$file"; then
    NGINX_CONF="$file"
    PORT=$(basename "$file" | cut -d'_' -f2)
    break
  fi
done

if [[ -z "$NGINX_CONF" || -z "$PORT" ]]; then
  echo "❌ Tidak ditemukan file konfigurasi Nginx untuk folder ini."
  exit 1
fi

# === Input berdasarkan mode ===
if [[ "$MODE" == "1" ]]; then
  IP_LAN=$(hostname -I | awk '{print $1}')
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

# === Modifikasi Konfigurasi Nginx ===
if [[ "$MODE" == "1" ]]; then
  echo "🧹 Menghapus blokir Nginx (mode LOCAL)"
  sed -i '/# AUTO-BLOCK START/,/# AUTO-BLOCK END/d' "$NGINX_CONF"

  echo "🧹 Mode LOCAL dipilih"
  rm -f "$WP_DIR/.domain"

  # Ganti server_name ke localhost
  sed -i "s/server_name .*/server_name localhost;/" "$NGINX_CONF"

  # Hapus blokir IP (deny all)
  sed -i '/# STATIC-BLOCK START/,/# STATIC-BLOCK END/d' "$NGINX_CONF"

  # Tambah blokir domain (via host header)
  if ! grep -q "# HOST-FILTER START" "$NGINX_CONF"; then
    sed -i "/server_name/a \ \ \ \ # HOST-FILTER START\n    if (\$host !~ \"^localhost\$|^127\.0\.0\.1\$|^192\.168\..*\") { return 444; }\n    # HOST-FILTER END" "$NGINX_CONF"
  fi

  nginx -t && systemctl reload nginx
  echo "✅ Sekarang hanya bisa diakses via IP: http://$(hostname -I | awk '{print $1}'):$PORT"

elif [[ "$MODE" == "2" ]]; then
  echo "🔒 Menambahkan blokir wp-login.php dan wp-admin di $NGINX_CONF"
  if ! grep -q "# AUTO-BLOCK START" "$NGINX_CONF"; then
    sed -i "/server_name/a \\\n    # AUTO-BLOCK START\n    location = /wp-login.php { return 404; }\n    location = /wp-admin { return 404; }\n    # AUTO-BLOCK END\n" "$NGINX_CONF"
  else
    echo "ℹ️ Blokir sudah ada di konfigurasi Nginx"
  fi

  echo "🌐 Mode PUBLIC dipilih"
  read -rp "🌐 Masukkan domain publik (contoh: static.domain.com): " DOMAIN
  echo "$DOMAIN" > "$WP_DIR/.domain"

  # Ganti server_name ke domain
  sed -i "s/server_name .*/server_name $DOMAIN;/" "$NGINX_CONF"

  # Hapus blokir domain
  sed -i '/# HOST-FILTER START/,/# HOST-FILTER END/d' "$NGINX_CONF"

  # Tambahkan blokir IP jika belum ada
  if ! grep -q "# STATIC-BLOCK START" "$NGINX_CONF"; then
    sed -i "/location \/ {/i \ \ \ \ # STATIC-BLOCK START\n    allow 127.0.0.1;\n    deny all;\n    # STATIC-BLOCK END\n" "$NGINX_CONF"
  fi

  nginx -t && systemctl reload nginx
  echo "🔒 Sekarang hanya bisa diakses melalui domain: https://$DOMAIN"
fi

echo ""
echo "✅ Sinkronisasi selesai. Sekarang WordPress akan diarahkan ke:"
echo "$URL"
