# ⚙️ Minimal Panel Script Yubay

Kumpulan script Bash untuk mengelola instalasi WordPress berbasis LEMP stack (Linux, Nginx, MariaDB, PHP). Dirancang agar bisa diakses secara lokal maupun publik (via domain seperti Cloudflare Tunnel). Cocok untuk digunakan di server ringan seperti Armbian STB dengan OS Armbian Server.

---

## 📁 Daftar Script

| File               | Fungsi                                                                 |
|--------------------|------------------------------------------------------------------------|
| `installer.sh`   | Instalasi WordPress + konfigurasi LEMP pada port tertentu              |
| `uninstaller.sh` | Menghapus instance WordPress (folder, database, user, Nginx conf)      |
| `listed.sh`      | Menampilkan daftar instance WordPress yang terinstal                   |
| `switcher.sh`    | Mengatur ulang URL (siteurl & home) ke IP lokal atau domain publik     |
| `cleaner.sh`     | Membersihkan cache, sampah, dan log sistem untuk optimasi server       |
| `staticweb.sh`   | Mengelola website static untuk HTML CSS JS PHP dan atau database       |

---

## 🚀 Cara Penggunaan Cepat
### 1. Download dan Install
```bash
# Download dan install
sudo curl -sSL https://raw.githubusercontent.com/soranewa/webserver/refs/heads/main/menu.sh -o /usr/local/bin/ybpanel
sudo chmod +x /usr/local/bin/ybpanel
# Jalankan
ybpanel

# Uninstall
sudo rm /usr/local/bin/yubay
