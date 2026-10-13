# Resonance

> A modern, interactive music & media streaming server.

Resonance turns your own media library into a personal streaming service —
with a real-time, interactive web UI, a clean REST + WebSocket API, and
clients for anything that speaks Subsonic, UPnP/DLNA, or plain HTTP.

---

## Table of Contents

- [Vision](#vision)
- [Features](#features)
- [Stack](#stack)
- [Architecture](#architecture)
- [Status](#status)
- [Quick Start](#quick-start)
- [Development](#development)
- [Configuration](#configuration)
- [Project Layout](#project-layout)
- [Roadmap](#roadmap)
- [Security](#security)
- [Contributing](#contributing)
- [License](#license)

---

## Vision

Most self-hosted media servers are either powerful but dated, or modern
but locked down. Resonance aims to be both **powerful** and **pleasant**:

- A **fast, real-time web UI** that feels like a native app.
- A **clean, documented API** so any client can talk to it.
- **Security by default** — modern crypto, no shortcuts.
- **Runs anywhere** — Docker Compose for the impatient, native Perl for
  the purists.

---

## Features

Planned and in-progress features:

- 🎵 **Music, video, podcasts, and radio** in one catalog
- 🔍 **Fast search** — Postgres full-text + trigram fuzzy matching
- 📻 **Direct HTTP streaming** with byte-range support (seek without download)
- 🧠 **Smart playlists** — rules, moods, BPM, sonic similarity
- ⚡ **Real-time updates** — scan progress, now-playing, library changes over WebSocket
- 🔐 **JWT auth** with refresh rotation + long-lived device tokens
- 👥 **Multi-user** with per-user libraries, playlists, and permissions
- 🔌 **Open API** — REST + WebSocket, plus a Subsonic-compatible endpoint
- 🎨 **Interactive frontend** — keyboard-driven, drag-drop playlists, live search
- 🐳 **Docker-first** deployment, with native install supported

---

## Stack

| Layer         | Technology                                              |
| ------------- | ------------------------------------------------------- |
| Backend       | Perl 5.36+, Mojolicious, Minion                         |
| Database      | PostgreSQL 16 (JSONB, full-text, `pg_trgm`)             |
| Cache / PubSub| Redis 7                                                 |
| Auth          | JWT (access + refresh), Argon2id password hashing       |
| Frontend      | Vue 3, Vite, Pinia, Vue Router, Tailwind CSS, Howler.js |
| Packaging     | Carton (Perl), npm (Node)                               |
| Runtime       | Docker Compose (recommended), or native                 |

---

## Architecture

```
┌────────────────┐    HTTPS / WSS    ┌──────────────────────┐
│  Vue 3 SPA     │ ◄───────────────► │  Mojolicious backend │
│  (Vite build)  │                   │  REST + WebSocket    │
└────────────────┘                   └──────────┬───────────┘
                                                │
                              ┌─────────────────┼─────────────────┐
                              │                 │                 │
                        ┌─────▼─────┐     ┌─────▼─────┐     ┌─────▼─────┐
                        │ Postgres  │     │  Redis    │     │  Minion   │
                        │ (data)    │     │ (cache,   │     │ (jobs,    │
                        │           │     │  pub/sub) │     │  scanner) │
                        └───────────┘     └───────────┘     └───────────┘
```

More detail in [`docs/`](docs/).

---

## Status

🚧 **Early development** — building phase by phase.

See [Roadmap](#roadmap) below, or [`docs/ROADMAP.md`](docs/ROADMAP.md).

---

## Quick Start

> Requires **Docker** and **Docker Compose**.

```bash
# 1. Clone
git clone git@github.com:thomas666-beast/resonance.git
cd resonance

# 2. Configure
cp .env.example .env
# edit .env and set real secrets
#   openssl rand -hex 64   → RESONANCE_SECRET_KEY

# 3. Start Postgres + Redis
docker compose up -d postgres redis

# 4. Verify
docker compose ps
```

Backend and frontend setup are covered in
[`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md) (added in Phase 1).

---

## Development

Detailed instructions land as each phase completes. Short version:

### Backend (Perl / Mojolicious)

```bash
cd backend
carton install          # first time only
carton exec -- perl bin/resonance daemon   # dev server
```

### Frontend (Vue 3)

```bash
cd frontend
npm install
npm run dev
```

### All services via Docker

```bash
docker compose up -d
```

---

## Configuration

All configuration is via environment variables. See
[`.env.example`](.env.example) for the full list and defaults.

Key variables:

| Variable                | Purpose                                      |
| ----------------------- | -------------------------------------------- |
| `RESONANCE_SECRET_KEY`  | 64-byte hex secret for signing JWTs          |
| `POSTGRES_*`            | Database connection                          |
| `REDIS_URL`             | Redis connection                             |
| `JWT_ACCESS_TTL`        | Access token lifetime (seconds)              |
| `JWT_REFRESH_TTL`       | Refresh token lifetime (seconds)             |
| `MEDIA_ROOT`            | Root path(s) of your media library           |

> **Never** commit your `.env` file. It is already gitignored.

---

## Project Layout

```
resonance/
├── backend/            # Mojolicious app
│   ├── lib/Resonance/  # application code
│   ├── bin/            # entrypoints (daemon, minion worker)
│   ├── etc/            # config templates
│   ├── migrations/     # SQL migrations
│   ├── script/         # dev scripts
│   ├── t/              # tests
│   └── public/         # static assets
├── frontend/           # Vue 3 app
├── docker/             # postgres + redis config
├── docs/               # architecture, roadmap, guides
├── scripts/            # dev helper scripts
├── docker-compose.yml
├── .env.example
├── .gitignore
├── .editorconfig
├── README.md
├── CONTRIBUTING.md
└── LICENSE
```

---

## Roadmap

| Phase | Goal                                 | Status |
| ----- | ------------------------------------ | ------ |
| 0     | Project skeleton                     | ✅     |
| 1     | Backend boots + Postgres + Redis     | ⏳     |
| 2     | Database schema + migrations         | ⏳     |
| 3     | Auth — JWT, refresh, device tokens   | ⏳     |
| 4     | Library scanning (Minion jobs)       | ⏳     |
| 5     | REST API — browse, search, stream    | ⏳     |
| 6     | Frontend boots + login + browse      | ⏳     |
| 7     | Player — queue, now-playing          | ⏳     |
| 8     | Realtime — WebSocket events          | ⏳     |
| 9     | Playlists + favorites                | ⏳     |
| 10    | Polish — transcode, themes, shortcuts| ⏳     |

---

## Security

Security is a first-class concern, not an afterthought:

- **Argon2id** for password hashing
- **JWT** access tokens (short-lived) + rotating refresh tokens
- **Prepared statements only** — no string-concatenated SQL
- **Strict CSP** and security headers by default
- **Rate limiting** on auth and streaming endpoints
- **Secrets** live only in `.env`, never in code or the repo
- **AGPL-3.0** ensures hosted forks stay open

If you find a vulnerability, please **do not open a public issue** —
contact the maintainer privately first.

---

## Contributing

Early-stage project. If you'd like to contribute, open an issue first
so we can align on direction. See [`CONTRIBUTING.md`](CONTRIBUTING.md).

---

## License

copy left
