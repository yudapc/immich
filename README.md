# Immich Self-Hosted

Setup [Immich](https://immich.app) (pengganti Google Photos yang di-host sendiri) menggunakan Docker Compose, dioptimalkan untuk hardware terbatas (Mac Mini 2014: maks 2 CPU & 4GB RAM), dengan akses publik melalui Cloudflare Tunnel.

## Komponen

| Service                   | Fungsi                                   | CPU   | RAM   |
|---------------------------|------------------------------------------|-------|-------|
| `immich-server`           | Web UI + API (port `2283`)               | 0.75  | 1.5GB |
| `immich-machine-learning` | Face recognition & smart search (opsional) | 0.5 | 1.5GB |
| `database`                | PostgreSQL + vector extension            | 0.5   | 768MB |
| `redis`                   | Cache/queue (Valkey)                     | 0.125 | 128MB |
| `tunnel`                  | Cloudflare Tunnel untuk akses dari luar  | 0.125 | 96MB  |

## Prasyarat

- [Docker](https://docs.docker.com/get-docker/) dan Docker Compose v2 (`docker compose version`)
- Akun Cloudflare dengan domain, jika ingin diakses dari internet (opsional)

## Setup

### 1. Clone repo

```bash
git clone <url-repo> immich
cd immich
```

### 2. Buat file `.env`

```bash
cp env-sample .env
chmod 600 .env   # hanya bisa dibaca oleh user Anda
```

Lalu edit `.env` dan isi minimal:

| Variabel                  | Keterangan                                                                 |
|---------------------------|----------------------------------------------------------------------------|
| `DB_PASSWORD`             | **Wajib.** Password database yang kuat. Gunakan hanya `A-Za-z0-9`.        |
| `UPLOAD_LOCATION`         | Folder penyimpanan foto/video (default `./library`)                       |
| `DB_DATA_LOCATION`        | Folder data PostgreSQL (default `./postgres`). Sebaiknya di SSD lokal.     |
| `IMMICH_VERSION`          | Versi Immich, misal `v2.5.2`. Jangan pakai `release` agar upgrade terkontrol. |
| `CLOUDFLARE_TUNNEL_TOKEN` | Token dari Cloudflare Zero Trust (lihat langkah 3)                        |

Membuat password acak:

```bash
openssl rand -hex 24
```

> ⚠️ **Jangan pernah commit `.env`.** File ini sudah ada di `.gitignore`.

### 3. Cloudflare Tunnel (opsional)

1. Buka **Cloudflare Zero Trust → Networks → Tunnels → Create a tunnel** (tipe *Cloudflared*).
2. Salin token-nya ke `CLOUDFLARE_TUNNEL_TOKEN` di `.env`.
3. Di tab **Public Hostname**, tambahkan hostname (misal `foto.domainanda.com`) dengan service `http://immich-server:2283`.

Jika tidak memakai tunnel, jalankan tanpa service tersebut:

```bash
docker compose up -d immich-server database redis
```

### 4. Jalankan

```bash
# Tanpa machine learning (~1.5 CPU / ~2.5GB RAM)
docker compose up -d

# Dengan machine learning (~2 CPU / ~4GB RAM)
docker compose --profile ml up -d
```

Buka `http://localhost:2283` (atau domain tunnel Anda). User pertama yang mendaftar otomatis menjadi **admin** — segera daftar setelah server jalan.

## Perintah Berguna

```bash
docker compose ps                         # status container
docker compose logs -f immich-server      # lihat log
docker compose down                       # stop semua
docker compose pull && docker compose up -d   # update image (setelah ganti IMMICH_VERSION)
```

Sebelum upgrade, baca [release notes Immich](https://github.com/immich-app/immich/releases) karena kadang ada breaking change.

## Backup

Yang perlu di-backup:

- **`UPLOAD_LOCATION`** (`./library`) — semua foto & video asli
- **Database** — dump secara berkala:

  ```bash
  docker exec -t immich_postgres pg_dumpall --clean --if-exists --username=immich \
    | gzip > immich-db-$(date +%F).sql.gz
  ```

- **`.env`** — simpan di password manager, bukan di git

Panduan lengkap: <https://docs.immich.app/administration/backup-and-restore>

## Keamanan

- `.env` berisi password dan token — permission `600`, jangan di-commit atau dibagikan.
- Jika `.env` pernah bocor (ter-commit, ter-push, dikirim lewat chat), **ganti** `DB_PASSWORD` dan buat ulang token Cloudflare Tunnel.
- Port `2283` terbuka ke jaringan lokal. Jika hanya diakses lewat tunnel, ubah menjadi `'127.0.0.1:2283:2283'` di `docker-compose.yml`.
- Gunakan password kuat untuk akun admin Immich, dan pertimbangkan Cloudflare Access di depan tunnel untuk lapisan login tambahan.

## Struktur Folder

```
.
├── docker-compose.yml   # definisi service
├── env-sample           # template .env
├── .env                 # konfigurasi rahasia (tidak di-commit)
├── library/             # foto & video (tidak di-commit)
├── postgres/            # data database (tidak di-commit)
└── model-cache/         # cache model ML (tidak di-commit)
```
