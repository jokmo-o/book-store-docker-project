# Book Shop — Dockerized Deployment

DevOps assignment for **Special Topics in Software Engineering 2** at Princess Sumaya University for Technology.
Containerizing a Django Book Shop application using Docker, Docker Compose, PostgreSQL, and Nginx as a reverse proxy.

## Team


- Hamza
- Abd
- Ehab

## Architecture

The stack runs as three containers on a shared bridge network:

| Service   | Image            | Port   | Purpose                                       |
|-----------|------------------|--------|-----------------------------------------------|
| `db`      | `postgres:15`    | 5432   | Persistent storage (named volume)             |
| `backend` | Custom (Django)  | 8000   | Book Shop application — views & templates    |
| `nginx`   | `nginx:alpine`   | 80     | Reverse proxy → backend, serves /static/     |

```
client → nginx:80 → backend:8000 → db:5432
```

## Prerequisites

- Docker 24+
- Docker Compose v2

## Getting Started

```bash
# 1. Clone
git clone https://github.com/<owner>/book-shop-docker.git
cd book-shop-docker

# 2. Configure environment
cp .env.example .env
# Edit .env and set real values for SECRET_KEY and POSTGRES_PASSWORD

# 3. Build & run
docker compose up --build
```

Then open <http://localhost> in your browser.

## Useful Commands

```bash
# Run Django migrations
docker compose exec backend python manage.py migrate

# Create superuser for admin panel
docker compose exec backend python manage.py createsuperuser

# View logs
docker compose logs -f backend

# Stop everything
docker compose down

# Stop and wipe the database volume (destructive)
docker compose down -v
```

## Project Structure

```
book-shop-docker/
├── book_shop/            # Django project source (from base repo)
├── Dockerfile            # Backend image definition
├── docker-compose.yml    # Service orchestration
├── nginx.conf            # Reverse proxy config
├── requirements.txt      # Python dependencies
├── .env.example          # Environment variable template
├── .gitignore
└── README.md
```

## Environment Variables

See `.env.example` for the full list. Required keys:

- `SECRET_KEY` — Django secret key
- `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` — database credentials
- `ALLOWED_HOSTS` — comma-separated allowed hostnames

## Task Tracking

- [ ] Write Dockerfile for backend (`feature/dockerfile`)
- [ ] Write docker-compose.yml (`feature/compose`)
- [ ] Migrate SQLite → PostgreSQL in settings.py (`feature/postgres-migration`)
- [ ] Write nginx.conf reverse proxy (`feature/nginx`)
- [ ] Verify end-to-end on a fresh clone
- [ ] Final README polish

## Notes

- `.env` is git-ignored. Each developer keeps their own local copy.
- The `db` service uses a named volume so data persists across `docker compose down`.
- Run `docker compose down -v` to wipe the database when you need a clean slate.
