#!/bin/bash
trap "exit" INT TERM ERR
trap "kill 0" EXIT

# === Konstanta ===
WEB_ROOT="/var/www"

# === Fungsi: Tampilkan Menu ===
show_mode_menu() {
  clear
  echo "======================================"
  echo "🔁 PILIH MODE AKSES WORDPRESS:"
  echo "1. Switch ke LOCAL (IP:PORT)"
  echo "2. Switch ke PUBLIC (Domain)"
  echo "0. Batal"
  echo "======================================"
}

# === Fungsi: Pilih Folder WordPress ===
select_wp_folder() {
  echo ""
  echo "📂 Folder WordPress yang tersedia:"
  FOLDERS=$(ls -1 "$WEB_ROOT")
  PS3="Pilih folder: "
  select WP_FOLDER in $FOLDERS; do
    [[ -n "$WP_FOLDER" ]] && break
    echo "❌ Pilihan tidak valid."
  done

  WP_DIR="$WEB_ROOT/$WP_FOLDER"
  WP_CONFIG="$WP_DIR/wp-config.php"

  if [[ ! -f "$WP_CONFIG" ]]; then
    echo "❌ wp-config.php tidak ditemukan di $WP_DIR"
    exit 1
  fi
}

# === Fungsi: Ambil Info DB dari wp-config.php ===
extract_db_info() {
  DB_NAME=$(grep DB_NAME "$WP_CONFIG" | cut -d "'" -f 4)
  DB_USER=$(grep DB_USER "$WP_CONFIG" | cut -d "'" -f 4)
  DB_PASS=$(grep DB_PASSWORD "$WP_CONFIG" | cut -d "'" -f 4)

  if [[ -z "$DB_NAME" || -z "$DB_USER" || -z "$DB_PASS" ]]; then
    echo "❌ Gagal baca info database dari wp-config.php"
    exit 1
  fi
}

# === Fungsi: Cari File NGINX untuk Folder WP ===
find_nginx_config() {
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
    echo "❌ Konfigurasi Nginx tidak ditemukan untuk folder ini."
    exit 1
  fi
}

# === Fungsi: Update Database siteurl dan home ===
update_wp_database_url() {
  echo "🛠️ Menyetel siteurl dan home di database ke: $URL"
  mysql -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "
  UPDATE wp_options SET option_value = '$URL' WHERE option_name = 'siteurl';
  UPDATE wp_options SET option_value = '$URL' WHERE option_name = 'home';
  "
}

# === Fungsi: Update Konfigurasi NGINX ===
update_nginx_config_wp() {
  local MODE="$1"
  local WP_DIR="$2"
  local NGINX_CONF="$3"
  local PORT="$4"

  if [[ "$MODE" == "1" ]]; then
    echo "🧹 Mode LOCAL dipilih"
    rm -f "$WP_DIR/.domain"

    # Hapus blokir wp-login.php dan wp-admin
    sed -i '/# AUTO-BLOCK START/,/# AUTO-BLOCK END/d' "$NGINX_CONF"

    # Ganti server_name ke localhost
    sed -i "s/server_name .*/server_name localhost;/" "$NGINX_CONF"

    nginx -t && systemctl reload nginx
    echo "✅ Sekarang hanya bisa diakses via IP: http://$(hostname -I | awk '{print $1}'):$PORT"

  elif [[ "$MODE" == "2" ]]; then
    read -rp "🌐 Masukkan domain publik (contoh: wp.domain.com): " DOMAIN
    echo "$DOMAIN" > "$WP_DIR/.domain"

    # Ganti server_name ke domain
    sed -i "s/server_name .*/server_name $DOMAIN;/" "$NGINX_CONF"

    # Tambahkan blokir wp-login.php dan wp-admin jika belum ada
    if ! grep -q "# AUTO-BLOCK START" "$NGINX_CONF"; then
      sed -i "/server_name/a \\\n    # AUTO-BLOCK START\n    location = /wp-login.php { return 404; }\n    location = /wp-admin { return 404; }\n    # AUTO-BLOCK END\n" "$NGINX_CONF"
    fi

    nginx -t && systemctl reload nginx
    echo "🔒 Sekarang hanya bisa diakses melalui domain: https://$DOMAIN"
  else
    echo "❌ Mode tidak valid untuk konfigurasi Nginx"
  fi
}

# === Fungsi: Jalankan Mode Switcher ===
run_mode_selector() {
  show_mode_menu
  read -rp "Pilih opsi (0-2): " MODE

  case "$MODE" in
    1|2)
      select_wp_folder
      extract_db_info
      find_nginx_config

      if [[ "$MODE" == "1" ]]; then
        IP_LAN=$(hostname -I | awk '{print $1}')
        URL="http://${IP_LAN}:${PORT}"
      elif [[ "$MODE" == "2" ]]; then
        read -rp "🌐 Masukkan domain publik (contoh: wp.domain.com): " DOMAIN
        URL="https://$DOMAIN"
      fi

      update_wp_database_url
      update_nginx_config_wp "$MODE" "$WP_DIR" "$NGINX_CONF" "$PORT"
      echo ""
      echo "✅ Sinkronisasi selesai. Sekarang WordPress akan diarahkan ke:"
      echo "$URL"
      ;;
    0)
      echo "❌ Dibatalkan."
      exit 0
      ;;
    *)
      echo "❌ Input tidak valid."
      sleep 1
      run_mode_selector
      ;;
  esac
}

# === Eksekusi Utama ===
if [[ $EUID -ne 0 ]]; then
  echo "❌ Script harus dijalankan sebagai root"
  exit 1
fi

run_mode_selector
