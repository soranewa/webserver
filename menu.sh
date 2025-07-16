#!/bin/bash
trap "exit" INT TERM ERR
trap "kill 0" EXIT

# Base URL raw GitHub tempat semua file kamu disimpan
BASE_URL="https://raw.githubusercontent.com/soranewa/webserver/refs/heads/main"

while true; do
  clear
  echo "==============================================="
  echo "🧰 STB WEBSERVER CONTROL PANEL"
  echo "==============================================="
  echo "1. Install WordPress & LEMP"
  echo "2. Switch Akses WordPress"
  echo "3. List WordPress Instance"
  echo "4. Uninstall WordPress & LEMP"
  echo "5. Kelola Website Static"
  echo "6. Pembersih Server"
  echo "0. Keluar"
  echo "==============================================="
  read -rp "Pilih opsi (0-6): " MENU

  case $MENU in
    1)
      echo "📦 Menjalankan Install WordPress & LEMP..."
      bash <(curl -s "$BASE_URL/installer.sh")
      ;;
    2)
      echo "🔁 Menjalankan Switch Akses WordPress..."
      bash <(curl -s "$BASE_URL/switcher.sh")
      ;;
    3)
      echo "📋 Menjalankan List WordPress Instance..."
      bash <(curl -s "$BASE_URL/listed.sh")
      ;;
    4)
      echo "🗑️ Menjalankan Uninstall WordPress & LEMP..."
      bash <(curl -s "$BASE_URL/uninstaller.sh")
      ;;
    5)
      echo "🛠️ Menjalankan Kelola Website Static..."
      bash <(curl -s "$BASE_URL/staticweb.sh")
      ;;
    6)
      echo "🧹 Menjalankan Pembersih Server..."
      bash <(curl -s "$BASE_URL/cleaner.sh")
      ;;
    0)
      echo "👋 Keluar dari panel."
      exit 0
      ;;
    *)
      echo "❌ Pilihan tidak valid."
      ;;
  esac

  echo ""
  read -rp "Tekan Enter untuk kembali ke menu..."
done
