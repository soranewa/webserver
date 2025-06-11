#!/bin/bash

# === Fungsi Validasi ===
valid_port() {
  [[ $1 =~ ^[0-9]+$ ]] && [ "$1" -ge 1024 ] && [ "$1" -le 65535 ]
}

# === Cek Root ===
if [[ $EUID -ne 0 ]]; then
  echo "Harus dijalankan sebagai root!"
  exit 1
fi

# === Update & Install LEMP ===
echo "🔍 Mengecek apakah LEMP sudah terinstall..."

if ! command -v nginx >/dev/null; then
    echo "🧱 Menginstall Nginx..."
    apt install -y nginx
    systemctl enable nginx
    systemctl start nginx
fi

if ! command -v mysql >/dev/null; then
    echo "🛢️ Menginstall MariaDB..."
    apt install -y mariadb-server
    systemctl enable mariadb
    systemctl start mariadb
fi

if ! php -v >/dev/null 2>&1; then
    echo "🐘 Menginstall PHP & modul..."
    apt install -y php php-fpm php-mysql php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip unzip curl
    systemctl enable php7.4-fpm 2>/dev/null || true
    systemctl start php7.4-fpm 2>/dev/null || true
fi

# Enable service
systemctl enable nginx
systemctl enable mariadb
systemctl enable php7.4-fpm 2>/dev/null || true

# Start service
systemctl start nginx
systemctl start mariadb
systemctl start php7.4-fpm 2>/dev/null || true

# === Input User ===
echo -e "\n📥 Masukkan PORT untuk WordPress instance:"
read -rp "Port (1024-65535): " WP_PORT
until valid_port "$WP_PORT"; do
  echo "❌ Port tidak valid!"
  read -rp "Port (1024-65535): " WP_PORT
done

read -rp "📁 Nama folder instalasi WordPress (contoh: wp_blog1): " WP_FOLDER
WP_DIR="/var/www/$WP_FOLDER"

while [[ -z "$WP_FOLDER" || -d "$WP_DIR" ]]; do
  if [[ -d "$WP_DIR" ]]; then
    echo "❌ Direktori $WP_DIR sudah ada. Masukkan nama folder baru!"
  fi
  read -rp "Nama folder baru: " WP_FOLDER
  WP_DIR="/var/www/$WP_FOLDER"
done

# === Input Database ===
DB_NAME="wp$(date +%s)"
DB_USER="user_${RANDOM}"
DB_PASS=$(openssl rand -base64 12)

# Buat direktori
mkdir -p "$WP_DIR"
chown -R www-data:www-data "$WP_DIR"

# === Download WordPress ===
echo "⬇️ Mengunduh WordPress..."
wget https://wordpress.org/latest.zip -O /tmp/latest.zip
unzip -q /tmp/latest.zip -d /tmp/
mv /tmp/wordpress/* "$WP_DIR"
rm -rf /tmp/latest.zip /tmp/wordpress

# === Konfigurasi Database ===
echo "🛠️ Mengatur database..."
mysql -e "CREATE DATABASE $DB_NAME DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
mysql -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# === wp-config.php ===
cp "$WP_DIR/wp-config-sample.php" "$WP_DIR/wp-config.php"
safe_db_name=$(printf '%s' "$DB_NAME" | sed -e 's/[\/&\\]/\\&/g')
safe_db_user=$(printf '%s' "$DB_USER" | sed -e 's/[\/&\\]/\\&/g')
safe_db_pass=$(printf '%s' "$DB_PASS" | sed -e 's/[\/&\\]/\\&/g')

sed -i "s/database_name_here/$safe_db_name/" "$WP_DIR/wp-config.php"
sed -i "s/username_here/$safe_db_user/" "$WP_DIR/wp-config.php"
sed -i "s/password_here/$safe_db_pass/" "$WP_DIR/wp-config.php"

# Set permission untuk hindari form "Connection Information"
sudo chown -R www-data:www-data "$WP_DIR"
sudo find "$WP_DIR" -type d -exec chmod 755 {} \;
sudo find "$WP_DIR" -type f -exec chmod 644 {} \;

# Tambahkan salt keys (disisipkan sebelum "That's all, stop editing!")
SALT=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
sed -i "/AUTH_KEY/d;/SECURE_AUTH_KEY/d;/LOGGED_IN_KEY/d;/NONCE_KEY/d;/AUTH_SALT/d;/SECURE_AUTH_SALT/d;/LOGGED_IN_SALT/d;/NONCE_SALT/d" "$WP_DIR/wp-config.php"
sed -i "/^\/\* That’s all.*/i $SALT" "$WP_DIR/wp-config.php"

# === Konfigurasi Nginx ===
NGINX_CONF="/etc/nginx/sites-available/wp_$WP_PORT"
cat > "$NGINX_CONF" <<EOF
server {
    listen $WP_PORT;
    root $WP_DIR;
    index index.php index.html;
    server_name localhost;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php7.4-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/

nginx -t && systemctl reload nginx

echo -e "\n✅ Instalasi WordPress berhasil!"
echo "🔗 Akses WordPress Anda di: http://$(hostname -I | awk '{print $1}'):$WP_PORT"
echo "📁 Direktori: $WP_DIR"
echo "🗃️ DB: $DB_NAME, User: $DB_USER, Pass: $DB_PASS"
