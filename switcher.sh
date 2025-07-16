#!/bin/bash
trap "exit" INT TERM ERR
trap "kill 0" EXIT

# === Root Check ===
if [[ $EUID -ne 0 ]]; then
  echo "❌ Script harus dijalankan sebagai root"
  exit 1
fi

# === Variabel Global ===
WEB_ROOT="/var/www"

# === Fungsi: Tampilkan menu mode akses ===
show_mode_menu() {
  clear
  echo "======================================"
  echo "🔁 PILIH MODE AKSES WORDPRESS:"
  echo "1. Switch ke LOCAL (IP:PORT)"
  echo "2. Switch ke PUBLIC (Domain)"
  echo "0. Batal"
  echo "======================================"
}

# === Fungsi: Pilih folder WordPress ===
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

# === Fungsi: Ambil info database dari wp-config.php ===
extract_db_info() {
  DB_NAME=$(grep DB_NAME "$WP_CONFIG" | cut -d "'" -f 4)
  DB_USER=$(grep DB_USER "$WP_CONFIG" | cut -d "'" -f 4)
  DB_PASS=$(grep DB_PASSWORD "$WP_CONFIG" | cut -d "'" -f 4)

  if [[ -z "$DB_NAME" || -z "$DB_USER" || -z "$DB_PASS" ]]; then
    echo "❌ Gagal baca info database dari wp-config.php"
    exit 1
  fi
}

# === Fungsi: Temukan konfigurasi nginx ===
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

# === Fungsi: Update siteurl dan home di database ===
update_wp_database_url() {
  echo "🛠️ Menyetel siteurl dan home di database ke: $URL"
  mysql -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "
    UPDATE wp_options SET option_value = '$URL' WHERE option_name = 'siteurl';
    UPDATE wp_options SET option_value = '$URL' WHERE option_name = 'home';
  "
}

# === Fungsi: Modifikasi konfigurasi nginx ===
modify_nginx_config() {
  if [[ "$MODE" == "1" ]]; then
    echo "🧹 Mode LOCAL dipilih"
    rm -f "$WP_DIR/.domain"

    # Ganti server_name ke localhost
    sed -i "s/server_name .*/server_name localhost;/" "$NGINX_CONF"

    # Hapus blokir wp-login dan wp-admin
    sed -i '/# AUTO-BLOCK START/,/# AUTO-BLOCK END/d' "$NGINX_CONF"

    # Hapus IP block
    sed -i '/# STATIC-BLOCK START/,/# STATIC-BLOCK END/d' "$NGINX_CONF"

    # Tambahkan host filter jika belum ada
    if ! grep -q "# HOST-FILTER START" "$NGINX_CONF"; then
      sed -i "/server_name/a \ \ \ \ # HOST-FILTER START\n    if (\$host !~ \"^localhost\$|^127\.0\.0\.1\$|^192\.168\..*\") { return 444; }\n    # HOST-FILTER END" "$NGINX_CONF"
    fi

    nginx -t && systemctl reload nginx
    echo "✅ Sekarang hanya bisa diakses via IP: http://$(hostname -I | awk '{print $1}'):$PORT"

  elif [[ "$MODE" == "2" ]]; then
    echo "$TARGET" > "$WP_DIR/.domain"

    echo "🌐 Mode PUBLIC dipilih"

    # Ganti server_name ke domain
    sed -i "s/server_name .*/server_name $TARGET;/" "$NGINX_CONF"

    # Hapus host filter
    sed -i '/# HOST-FILTER START/,/# HOST-FILTER END/d' "$NGINX_CONF"

    # Tambahkan IP block jika belum ada
    if ! grep -q "# STATIC-BLOCK START" "$NGINX_CONF"; then
      sed -i "/location \/ {/i \ \ \ \ # STATIC-BLOCK START\n    allow 127.0.0.1;\n    deny all;\n    # STATIC-BLOCK END\n" "$NGINX_CONF"
    fi

    # Tambahkan blokir wp-login dan wp-admin jika belum ada
    if ! grep -q "# AUTO-BLOCK START" "$NGINX_CONF"; then
      sed -i "/server_name/a \\\n    # AUTO-BLOCK START\n    location = /wp-login.php { return 404; }\n    location = /wp-admin { return 404; }\n    # AUTO-BLOCK END\n" "$NGINX_CONF"
    else
      echo "ℹ️ Blokir wp-login dan wp-admin sudah ada"
    fi

    nginx -t && systemctl reload nginx
    echo "🔒 Sekarang hanya bisa diakses melalui domain: https://$TARGET"
  fi
}

# === Fungsi Utama: Jalankan alur utama script ===
main() {
  show_mode_menu
  read -rp "Pilih opsi (0-2): " MODE

  case "$MODE" in
    1)
      select_wp_folder
      extract_db_info
      find_nginx_config
      IP_LAN=$(hostname -I | awk '{print $1}')
      URL="http://${IP_LAN}:${PORT}"
      modify_nginx_config
      update_wp_database_url
      ;;
    2)
      select_wp_folder
      extract_db_info
      find_nginx_config
      read -rp "🌐 Masukkan domain publik (contoh: static.domain.com): " TARGET
      URL="https://$TARGET"
      modify_nginx_config
      update_wp_database_url
      ;;
    0)
      echo "❌ Dibatalkan."
      exit 0
      ;;
    *)
      echo "❌ Input tidak valid."
      exit 1
      ;;
  esac

  echo ""
  echo "✅ Sinkronisasi selesai. Sekarang WordPress akan diarahkan ke:"
  echo "$URL"
}

# === Eksekusi ===
main
