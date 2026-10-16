# Resonance

> A modern, self-hosted music server with podcasts, internet radio, lyrics,
> a real-time web UI, and full Subsonic compatibility — so your library works
> from any browser and from every Subsonic client on any device.

Resonance turns your own collection into a personal streaming service. It
scans your files, extracts tags and album art, indexes genres and lyrics,
serves audio with HTTP Range support, and lets you browse, search, favorite,
build playlists, follow podcasts, and add internet radio — all from a fast,
dark-by-default interface.

---

## Table of Contents

- [Features](#features)
- [Screenshots](#screenshots)
- [Stack](#stack)
- [Requirements](#requirements)
- [Installation](#installation)
- [Configuration](#configuration)
- [Running](#running)
- [First-time setup](#first-time-setup)
- [Using Subsonic clients](#using-subsonic-clients)
- [Transcoding](#transcoding)
- [Lyrics](#lyrics)
- [Podcasts](#podcasts)
- [Internet radio](#internet-radio)
- [Maintenance](#maintenance)
- [Project layout](#project-layout)
- [Development](#development)
- [Testing](#testing)
- [Roadmap](#roadmap)
- [Security](#security)
- [License](#license)

---

## Features

- 🎵 **Music library** — scan folders, extract tags and cover art, browse by artist, album, or track
- 🎼 **Genres** — indexed per track, browsable, exposed to Subsonic clients
- 🔍 **Fast search** — Postgres full-text and trigram fuzzy matching across artists, albums, and tracks
- 🎤 **Lyrics** — local `.lrc` files, LRCLIB fallback, synced highlight in the web UI, and
  `getLyricsBySongId` for clients that support it
- ▶️ **Persistent player** — plays across navigation, with a full-screen now-playing view
- 📋 **Queue** — view, jump, drag-reorder, and remove upcoming tracks
- ❤️ **Favorites** — heart any track; everything syncs to Subsonic clients
- 📼 **Playlists** — create, edit, drag-reorder, share
- 🖼️ **Album art** — extracted from embedded tags, cached to disk
- 🎙️ **Podcasts** — subscribe to RSS/Atom feeds, background refresh, download-and-cache
  playback, per-user listen progress, cache management
- 📻 **Internet radio** — add stations, stream through the server, ICY "now playing"
  titles pushed live to the UI
- ⚡ **Real-time updates** — WebSocket channels for scan progress, now-playing, and
  podcast refresh events
- 🌐 **Subsonic + OpenSubsonic** — works with DSub, Symfonium, play:Sub, Sonixd,
  Ultrasonic, substreamer, AntennaPod, and more
- 🎛️ **On-the-fly transcoding** — serve FLAC as MP3/Opus/AAC at any bitrate, cached
- 🗑️ **Missing file handling** — absent tracks are soft-deleted, hidden from every client,
  and manageable from the admin panel
- 🌓 **Dark mode by default** — light mode toggle, follows system preference
- 🎨 **Keyboard shortcuts** — Space, arrows, `f`, `/`, and more
- 🔐 **JWT auth** — HttpOnly refresh cookie, rotating tokens, per-device API tokens
- 👥 **Multi-user** — admin panel, roles, per-user libraries
- 🌍 **i18n-ready** — English shipped; add locales by dropping in a JSON file

---

## Screenshots

_Add your own — `docs/screenshots/` is a good place._

---

## Stack

| Layer           | Technology                                                    |
| --------------- | ------------------------------------------------------------- |
| Backend         | Perl 5.36+, Mojolicious, Minion                               |
| Database        | PostgreSQL 16 (`tsvector`, `pg_trgm`, JSONB)                  |
| Cache / PubSub  | Redis 7                                                       |
| Frontend        | Vue 3, Vite, Pinia, Vue Router, Tailwind CSS v4, Howler.js    |
| Auth            | JWT (HS256), Argon2id password hashing, AES-256-GCM at rest   |
| Lyrics          | Local `.lrc` files + [LRCLIB](https://lrclib.net) fallback    |
| Podcasts        | RSS 2.0 and Atom parsing via `XML::LibXML`                    |
| Packaging       | Carton (Perl), npm (Node)                                     |
| Optional        | ffmpeg (for transcoding and podcast episode caching)          |

---

## Requirements

**Runtime:**

- **Perl** 5.36 or newer
- **PostgreSQL** 16 or newer
- **Redis** 7 or newer
- **Node.js** 20 or newer (for building the frontend)
- **ffmpeg** (optional, for transcoding)

**Build tools** (for compiling XS modules like `Audio::Scan`, `CryptX`, `XML::LibXML`):

- A C compiler (`gcc` or `clang`)
- `make`
- Headers for OpenSSL, zlib, libpq, libxml2
- On Debian/Ubuntu: `build-essential libssl-dev zlib1g-dev libpq-dev libxml2-dev`
- On Fedora/RHEL: `gcc make openssl-devel zlib-devel postgresql-devel libxml2-devel`
- On FreeBSD: `pkg install gmake libxml2 p5-App-cpanminus`

---

## Installation

### 1. Clone

```bash
git clone https://github.com/thomas666-beast/resonance.git
cd resonance
```

### 2. Install PostgreSQL and Redis

**Option A — use Docker Compose just for the databases** (recommended):

```bash
docker compose up -d postgres redis
```

That starts Postgres on `127.0.0.1:5432` and Redis on `127.0.0.1:6379`,
with data stored in named Docker volumes.

**Option B — install natively:**

```bash
# Debian/Ubuntu
sudo apt install postgresql redis-server

# Fedora
sudo dnf install postgresql-server redis

# macOS (Homebrew)
brew install postgresql@16 redis

# FreeBSD
sudo pkg install postgresql16-server redis
```

Then create the database user and database:

```bash
sudo -u postgres psql <<'SQL'
CREATE USER resonance WITH PASSWORD 'change-me';
CREATE DATABASE resonance OWNER resonance;
CREATE DATABASE resonance_test OWNER resonance;
SQL
```

`resonance_test` is only needed if you want to run the test suite.

### 3. Configure

```bash
cp .env.example .env
```

Generate a JWT secret:

```bash
openssl rand -hex 64
```

Copy the output into `.env`. Then edit the rest:

```dotenv
RESONANCE_ENV=development
RESONANCE_LOG_LEVEL=debug

POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=resonance
POSTGRES_USER=resonance
POSTGRES_PASSWORD=change-me

REDIS_URL=redis://localhost:6379/0

JWT_SECRET=<your-64-byte-hex-from-openssl>
JWT_ACCESS_TTL=900
JWT_REFRESH_TTL=2592000
ALLOW_REGISTRATION=1

MEDIA_ROOT=/absolute/path/to/your/music
COVER_CACHE_DIR=/absolute/path/to/resonance/backend/data/covers
TRANSCODE_CACHE_DIR=/absolute/path/to/resonance/backend/data/transcodes
PODCAST_CACHE_DIR=/absolute/path/to/resonance/backend/data/podcasts

APP_NAME=Resonance
APP_COPYRIGHT_YEAR=2026
ADMIN_CONTACT=you@example.com
```

**Always use absolute paths** for `MEDIA_ROOT`, `COVER_CACHE_DIR`,
`TRANSCODE_CACHE_DIR`, and `PODCAST_CACHE_DIR`. The web server and the Minion
worker may run from different working directories — relative paths would
resolve differently.

### 4. Install Perl dependencies

```bash
cd backend
carton install
```

This downloads and compiles every module into `backend/local/`. It may take
several minutes the first time, especially for `Audio::Scan` and `XML::LibXML`.

### 5. Apply database migrations

```bash
carton exec -- ./script/migrate up
```

### 6. Install frontend dependencies and build

```bash
cd ../frontend
npm install
npm run build
```

The build outputs to `frontend/dist/`.

---

## Configuration

All configuration is via environment variables, loaded from `.env` at the repo
root. Key variables:

| Variable                | Purpose                                                       |
| ----------------------- | ------------------------------------------------------------- |
| `RESONANCE_ENV`         | `development` or `production` — affects cookie `Secure` flag  |
| `RESONANCE_LOG_LEVEL`   | `debug`, `info`, `warn`, `error`                              |
| `POSTGRES_HOST`         | Postgres host                                                 |
| `POSTGRES_PORT`         | Postgres port (default 5432)                                  |
| `POSTGRES_DB`           | Database name                                                 |
| `POSTGRES_USER`         | Database user                                                 |
| `POSTGRES_PASSWORD`     | Database password                                             |
| `POSTGRES_DSN`          | Optional full DSN — overrides the composed one                |
| `REDIS_URL`             | Redis connection string                                       |
| `JWT_SECRET`            | 64-byte hex secret for signing tokens                         |
| `JWT_ACCESS_TTL`        | Access token lifetime in seconds (default 900)                |
| `JWT_REFRESH_TTL`       | Refresh token lifetime in seconds (default 2592000)           |
| `ALLOW_REGISTRATION`    | `1` to allow public signup, `0` to disable                    |
| `MEDIA_ROOT`            | Absolute path to your music library (used by scans)           |
| `COVER_CACHE_DIR`       | Absolute path where extracted covers are stored               |
| `TRANSCODE_CACHE_DIR`   | Absolute path where transcoded audio is cached                |
| `PODCAST_CACHE_DIR`     | Absolute path where podcast episode audio is cached           |
| `APP_NAME`              | Shown in the footer (default `Resonance`)                     |
| `APP_COPYRIGHT_YEAR`    | Footer copyright year (default: current year)                 |
| `ADMIN_CONTACT`         | Footer contact — an email or URL; omitted when empty          |

> **Never** commit your `.env` file. It is already in `.gitignore`.

---

## Running

You need **four processes** running:

### 1. Postgres and Redis

If you're using Docker Compose:

```bash
docker compose up -d postgres redis
```

### 2. Web server

```bash
cd backend
carton exec -- ./bin/resonance daemon --listen http://127.0.0.1:3000
```

### 3. Minion worker

In a separate terminal:

```bash
cd backend
carton exec -- ./bin/resonance-minion
```

The worker processes background jobs — scanning, podcast refresh, transcode
cleanup.

### 4. Frontend

**For development** (hot reload, port 5173):

```bash
cd frontend
npm run dev
```

Then open `http://localhost:5173`.

**For production** (serves built assets from `frontend/dist/`):

```bash
cd frontend
npm run build
npm run preview
```

For a real production setup, put the built frontend behind nginx (or Caddy)
and reverse-proxy `/api` and `/rest` to the backend. `frontend/nginx.conf` is
a working example.

---

## First-time setup

### Create an admin user

```bash
cd backend
carton exec -- ./script/create-admin --username admin --email you@example.com
```

You'll be prompted for a password (no echo). This user gets `role = 'admin'`
and can access `/admin`.

### Scan your library

1. Log in to the web UI.
2. Click **Scan library** in the sidebar or header.
3. Watch the progress bar — files are ingested in real time, and missing
   files are marked in a second pass.

The scanner reads `MEDIA_ROOT`. It walks the tree, extracts tags, upserts
artist/album/track rows, indexes genres, extracts album art, and picks up any
`.lrc` files it finds next to audio files.

### Configure Subsonic (optional)

If you want to use third-party clients (DSub, Symfonium, play:Sub, Sonixd,
AntennaPod, Amperfy):

1. Go to **Settings** (gear icon).
2. Set a **Subsonic password**. This is a separate password from your login.
   It's stored encrypted with AES-256-GCM and never leaves your server.
3. Point your client at `http://your-server:3000`, using your username and the
   Subsonic password.

---

## Using Subsonic clients

Resonance implements the Subsonic 1.16.1 REST protocol plus a subset of
OpenSubsonic extensions. Any compatible client works.

**Tested clients:**

- **Android:** DSub, Symfonium, Ultrasonic, substreamer, AntennaPod
- **iOS:** play:Sub, Amperfy, substreamer
- **Desktop:** Sonixd, Supersonic, Feishin

**Setup in any client:**

| Field    | Value                                                    |
| -------- | -------------------------------------------------------- |
| Server   | `http://your-host:3000` (or your reverse-proxied URL)    |
| Username | Your Resonance username                                  |
| Password | Your **Subsonic password** (from Settings)               |

Clients can authenticate using token-based auth (`t`/`s` params) or legacy
password auth — both are supported.

**Implemented endpoints** include:

- Core: `ping`, `getLicense`, `getMusicFolders`, `getOpenSubsonicExtensions`
- Browsing: `getIndexes`, `getArtists`, `getArtist`, `getAlbum`, `getSong`,
  `getAlbumList` / `getAlbumList2`, `getRandomSongs`, `search3`
- Media: `stream`, `download`, `getCoverArt`
- Genres: `getGenres`, `getSongsByGenre`
- Favorites: `star`, `unstar`, `getStarred` / `getStarred2`
- Playlists: `getPlaylists`, `getPlaylist`, `createPlaylist`, `updatePlaylist`,
  `deletePlaylist`
- Podcasts: `getPodcasts`, `getNewestPodcasts`, `getPodcastEpisode`,
  `createPodcastChannel`, `deletePodcastChannel`, `refreshPodcasts`,
  `downloadPodcastEpisode`, `deletePodcastEpisode`
- Radio: `getInternetRadioStations`
- Lyrics: `getLyrics`, `getLyricsBySongId`
- Play history: `scrobble`
- Scanning: `getScanStatus`, `startScan`

**Advertised OpenSubsonic extensions:** `formPost`, `transcodeOffset`,
`songLyrics`.

---

## Transcoding

If `ffmpeg` is on the `PATH`, Resonance can transcode on the fly:

```
GET /api/stream/42?format=mp3&bitrate=192
GET /api/stream/42?format=opus&bitrate=128
GET /api/stream/42?format=aac&bitrate=192
```

Subsonic clients use `?format=` and `?maxBitRate=` transparently.

**Behavior:**

- Transcodes are cached on disk under `TRANSCODE_CACHE_DIR`.
- The cache key is `(track_id, source_mtime, format, bitrate)` — re-scanning a
  changed file automatically invalidates its transcode.
- If ffmpeg is unavailable or fails, the original file is served instead.
  Playback never breaks.
- Supported formats: `mp3`, `opus`, `aac`. Supported bitrates: 64, 96, 128,
  192, 256, 320.

**Cleanup:**

```bash
cd backend
carton exec -- ./script/transcode-cleanup 30
```

Removes transcoded files older than 30 days. Run via cron or a systemd timer.

You can also see the cache size and clear it from **Admin → Transcode cache**.

---

## Lyrics

Lyrics come from two sources, checked in order:

1. **Local `.lrc` files** next to your audio files. The scanner indexes them
   during a normal scan. Matching is by filename (`song.flac` → `song.lrc`),
   case-insensitive on the extension.
2. **LRCLIB** — a free, no-auth, open API. Used when no local file exists.
   Results are cached in the database, so subsequent requests are instant.

If neither source has anything, the UI shows "No lyrics available for this
track."

**Synced lyrics** (with timestamps) are highlighted as the track plays and
auto-scroll to the current line in the web UI. Plain text is shown as a
scrollable block. The Subsonic `getLyricsBySongId` endpoint returns the timed
structure for clients that support it.

**To add lyrics manually:** drop a `.lrc` file next to the audio file and
rescan. Existing lyrics are replaced on rescan if the file changed.

---

## Podcasts

Subscribe to any RSS 2.0 or Atom podcast feed.

**How it works:**

1. Paste the feed URL into **Podcasts → Subscribe**.
2. The feed is fetched in the background, parsed, and stored.
3. Episodes appear in the podcast detail page.
4. On first play, the episode is downloaded to `PODCAST_CACHE_DIR` and streamed
   from the local copy. Subsequent plays are instant.
5. Your listen position is tracked per user. Reopening an episode resumes from
   where you left off.

**Cache management:**

- **Per-episode** — from the podcast detail page, a "Remove download" button
  appears on cached episodes. Removing a download preserves your listen
  position.
- **Global** — **Admin → Podcast cache** shows total size and offers a
  "Clear cache" button.
- **CLI** — `script/cleanup-podcasts N` removes cached files older than N days:

  ```bash
  cd backend
  carton exec -- ./script/cleanup-podcasts 30
  ```

**Subsonic clients:** AntennaPod, Amperfy, and Symfonium can browse and play
podcasts through the standard Subsonic podcast endpoints.

---

## Internet radio

Add any Icecast/Shoutcast/HLS stream URL as a station. Admin-only for
add/edit/delete; all users can browse public stations.

**How it works:**

- The stream is proxied through the server, so HTTP-only streams work inside
  an HTTPS app, and CORS issues disappear.
- If the stream sends ICY metadata (`StreamTitle`), the current track title is
  extracted and pushed to the UI over WebSocket in real time.
- Clicking a station plays it in the shared player, with a LIVE indicator
  instead of a seek bar.

**Adding a station:** **Radio → Add station**. Provide at minimum a name and a
stream URL. Optional: genre, bitrate, logo, homepage.

**Subsonic clients:** the standard `getInternetRadioStations` endpoint is
available.

---

## Maintenance

### Backups

Back up two things:

1. **Postgres** — `pg_dump resonance > resonance.sql`
2. **Media on disk** — the four cache directories can be regenerated; the DB
   is the source of truth for the library

Your music files are never touched by Resonance. They live wherever you point
`MEDIA_ROOT`, and the app only reads them.

### Cleanup scripts

Three CLI tools for periodic housekeeping:

```bash
cd backend

# Remove cached transcodes older than N days
carton exec -- ./script/transcode-cleanup 30

# Remove cached podcast episodes older than N days
carton exec -- ./script/cleanup-podcasts 30

# Permanently delete tracks marked missing longer than N days
carton exec -- ./script/cleanup-missing 7
```

All three are safe to run from cron or a systemd timer.

### Updating

```bash
cd resonance
git pull

# Backend
cd backend
carton install
carton exec -- ./script/migrate up

# Frontend
cd ../frontend
npm install
npm run build
```

Restart the web server and worker.

### Logs

Everything is on stdout. Capture it via `systemd`, `supervisor`, or a process
manager. Alternatively, redirect to a file when starting:

```bash
carton exec -- ./bin/resonance daemon --listen http://127.0.0.1:3000 >> /var/log/resonance.log 2>&1
```

---

## Project layout

```
resonance/
├── backend/                  # Mojolicious application
│   ├── bin/                  # entrypoints (resonance, resonance-minion)
│   ├── lib/Resonance/        # application code
│   │   ├── Auth.pm           # Argon2id + JWT
│   │   ├── Controller/       # HTTP controllers
│   │   │   ├── Subsonic/     # Subsonic protocol layer
│   │   │   └── ...
│   │   ├── Job/              # Minion tasks (scan, podcast refresh)
│   │   ├── Lyrics/           # Parser + provider (local .lrc, LRCLIB)
│   │   ├── Plugin/           # auth, admin
│   │   ├── Podcast/          # RSS/Atom parser
│   │   ├── Scan/             # tag normalization
│   │   ├── Subsonic/         # Formatting, extensions
│   │   └── Util/             # Range, Transcode, PodcastFetch
│   ├── migrations/           # SQL migrations (Mojo::Pg format)
│   ├── script/               # migrate, create-admin, cleanup tools
│   ├── t/                    # test suite
│   └── cpanfile              # Perl dependencies
├── frontend/                 # Vue 3 SPA
│   ├── src/
│   │   ├── components/       # UI building blocks
│   │   ├── views/            # pages
│   │   ├── stores/           # Pinia stores
│   │   ├── composables/      # keyboard, etc.
│   │   ├── i18n/             # translations
│   │   ├── api/              # axios client
│   │   └── assets/           # logo, fonts
│   ├── nginx.conf            # production nginx config
│   └── package.json
├── docker-compose.yml        # Postgres + Redis only
├── .env.example
├── README.md
└── LICENSE
```

---

## Development

### Running the backend with hot reload

```bash
cd backend
carton exec -- ./bin/resonance daemon --listen http://127.0.0.1:3000 --reload
```

The `--reload` flag restarts the server on file changes.

### Running the frontend dev server

```bash
cd frontend
npm run dev
```

Vite proxies `/api` and `/rest` to the backend at port 3000. Cookies work
because both are same-origin from the browser's perspective.

### Adding a migration

Create a numbered directory under `backend/migrations/`:

```
backend/migrations/24/up.sql
```

Then run:

```bash
cd backend
carton exec -- ./script/migrate up
```

`Mojo::Pg::Migrations` requires the `<n>/up.sql` layout — plain numbered
`.sql` files at the top level will not be picked up.

### Adding a language

1. Copy `frontend/src/i18n/locales/en.json` to `fr.json` (or whatever).
2. Translate the values.
3. In `frontend/src/i18n/index.ts`, import the new locale, add it to
   `SUPPORTED` and `messages`.

The language dropdown in the user menu updates automatically.

---

## Testing

The test suite lives in `backend/t/`. It uses a **separate database**
(`resonance_test`) and drops/recreates the schema at the start of every test
file.

**One-time setup:**

```bash
docker compose exec postgres createdb -U resonance resonance_test
```

Or, on native Postgres:

```bash
sudo -u postgres createdb -O resonance resonance_test
```

**Run everything:**

```bash
cd backend
carton exec -- prove -l t/
```

Should complete in under a minute.

**Run one file:**

```bash
carton exec -- prove -lv t/11-api-library.t
```

**Coverage includes:**

- Authentication — register, login, refresh rotation, logout, device tokens
- Library — artists, albums, tracks, search, streaming with Range
- Favorites, playlists (CRUD, reorder, ownership), admin (permissions,
  self-protection, pagination)
- Subsonic — auth via password and token, browse, media, playlists, star,
  scrobble, podcast endpoints, lyrics endpoints
- Transcoding — fallback logic, cache stats, real ffmpeg when available
- Scanning — ingest from a temp folder, idempotency, missing-file
  reconciliation
- Genres — single, multi, case-insensitive dedup, rescan, clear
- Lyrics — LRC parser, local file lookup, cache hit

---

## Roadmap

Everything below is additive — the current app is complete and stable.

- **OpenSubsonic extensions beyond the current three** — richer metadata,
  multiple artists, sort keys
- **Lyrics editor** — manually fix or add lyrics for a track
- **Smart playlists** — rules-based (genre is X, year < Y, play count > Z)
- **Sharing** — public links to albums or playlists with an expiry
- **Podcast download now** — a button to pre-download an episode without
  playing it
- **External metadata enrichment** — bios, artist images, similar artists,
  MusicBrainz IDs
- **Docker packaging for the app itself** — one-command deploy
- **Crossfade and gapless playback**
- **Replay gain**
- **Mobile app** — the web UI is responsive, but a real app for offline
  playback would be nice

Contributions welcome. Open an issue first if it's a big change.

---

## Security

- Passwords hashed with **Argon2id**
- Access tokens are **short-lived JWTs** (15 min default)
- Refresh tokens are **HttpOnly, SameSite=Strict cookies**, rotated on every
  use; replay is rejected
- Subsonic passwords are stored **AES-256-GCM encrypted** with a key derived
  from `JWT_SECRET`
- All SQL uses **prepared statements**
- Security headers set globally (CSP, X-Frame-Options, X-Content-Type-Options,
  Referrer-Policy)
- File paths are never exposed through the API — Subsonic returns **synthetic
  paths**, not real filesystem paths

If you find a vulnerability, please **do not** open a public issue. Contact
the maintainer privately first.

---

## License

**MIT** — see [LICENSE](LICENSE).
