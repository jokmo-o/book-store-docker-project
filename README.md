# Book Shop — Docker Deployment

This is our submission for the Docker assignment in Special Topics in Software Engineering 2 at PSUT. The goal was to take an existing Django book shop app and containerize it with Docker Compose, PostgreSQL, and Nginx.

## Team

- Hamza Aldib
- Abdelrahman Qawaqzeh
- Ehab Hattab

## What we built

The app runs in three containers on a shared network:

- **db** — PostgreSQL 15 with a named volume so the data doesn't disappear when we stop the containers
- **backend** — Django app served by Gunicorn (we replaced runserver since it's not meant for production)
- **nginx** — reverse proxy on port 80, also serves the static files directly so Django doesn't have to

When a request comes in it goes: browser → nginx → backend → db. Static files like the admin CSS get served by nginx straight from a shared volume, which is faster than going through Django.

We added a healthcheck on the db so the backend doesn't try to connect before Postgres is actually ready. The first time we ran it without one we kept getting "connection refused" errors because Postgres takes a few seconds to start accepting connections after the container boots.

## Running it

```bash
git clone https://github.com/jokmo-o/book-store-docker-project.git
cd book-store-docker-project
cp .env.example .env
```

Open `.env` and set your own `SECRET_KEY` and `POSTGRES_PASSWORD`. The other values can stay as the defaults.

```bash
docker compose up --build
```

In another terminal:

```bash
docker compose exec backend python manage.py migrate
docker compose exec backend python manage.py createsuperuser
```

Then go to http://localhost and the bookshop should load. Admin is at http://localhost/admin.

## Useful commands

```bash
# stop everything but keep the data
docker compose down

# stop and wipe the database (we used this a lot while debugging)
docker compose down -v

# run any Django command
docker compose exec backend python manage.py <command>
```

## Environment variables

Everything goes through `.env` which is gitignored. The template is in `.env.example`.

Required:
- `SECRET_KEY`
- `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`

Optional (have defaults):
- `DEBUG` (default False)
- `ALLOWED_HOSTS` (default localhost,127.0.0.1)
- `POSTGRES_HOST` (default db)
- `POSTGRES_PORT` (default 5432)

## Files we wrote

- `Dockerfile` — for the backend container
- `docker-compose.yml` — wires everything together
- `nginx.conf` — proxy and static config
- `requirements.txt` — Django, Gunicorn, psycopg2-binary
- `.env.example` — template for the env file

The rest of the project is the original Django code from the assignment repo.