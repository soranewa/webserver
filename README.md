# ⚙️ Auto WordPress Setup Scripts

Kumpulan script Bash untuk mengelola instalasi WordPress berbasis LEMP stack (Linux, Nginx, MariaDB, PHP). Dirancang agar bisa diakses secara lokal maupun publik (via domain seperti Cloudflare Tunnel). Cocok untuk digunakan di server ringan seperti Armbian STB.

---

## 📁 Daftar Script

| File               | Fungsi                                                                 |
|--------------------|------------------------------------------------------------------------|
| `install-web.sh`   | Instalasi WordPress + konfigurasi LEMP pada port tertentu              |
| `uninstall-web.sh` | Menghapus instance WordPress (folder, database, user, Nginx conf)      |
| `list-web.sh`      | Menampilkan daftar instance WordPress yang terinstal                  |
| `switch.sh`        | Mengatur ulang URL (siteurl & home) ke IP lokal atau domain publik     |
| `bersih.sh`        | Membersihkan cache, sampah, dan log sistem untuk optimasi server       |

---

## 🚀 Cara Penggunaan

### 1. Clone Repository
```bash
git clone https://github.com/username/auto-wordpress-setup.git
cd auto-wordpress-setup
