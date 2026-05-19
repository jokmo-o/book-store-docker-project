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

## Phase 2 — CI/CD Pipelines

Phase 2 adds three GitHub Actions pipelines on top of the Phase 1 Dockerized stack — one per branch (`dev`, `test`, `prod`) — each implementing a different deployment philosophy. All three deploy to the same EC2 instance in `eu-central-1` and coexist there without interfering with each other.

### Branch strategy

The repo runs three long-lived branches. Each is wired to its own workflow under `.github/workflows/`, and each follows a deliberately different model of what "deployment" means.

**`dev` — artifact-first.** Every push triggers `dev.yml`. The workflow packages the application source, collected static files, and frozen dependencies into a single tarball (`app-<sha>.tar.gz`), commits it to `artifacts/` on the dev branch as an append-only audit trail, then builds the Docker image *from that committed artifact* — the Dockerfile `COPY`s the tarball into the image and extracts it. It does not reinstall from source. The image is then deployed to EC2 under the `bookshop-dev` compose project.

**`test` — image-first.** Every push to `test` (typically a merge from `dev`) triggers `test.yml`. The workflow rebuilds a fresh artifact from source — it does **not** reuse the artifact committed by the dev pipeline — builds the Docker image, pushes it to AWS ECR with the run number as the tag, and deploys to EC2 under `bookshop-test` by pulling the image it just pushed.

**`prod` — promotion only.** Every push or merge to `prod` triggers `prod.yml`. The workflow reads the `IMAGE_VERSION` repository variable, pulls the image tagged with that version from ECR, and deploys it to EC2 under `bookshop-prod`. There is no `docker build` anywhere in this workflow — promoting a new version to production means updating `vars.IMAGE_VERSION` in repo settings, not changing code.

### Why three philosophies

The three pipelines are intentionally different because each proves a different property of the delivery system:

- **dev** proves *we can ship exactly what we built*. The artifact is the unit of truth — once committed, the running container contains precisely those bytes, regardless of any later changes to git.
- **test** proves *we can rebuild reproducibly from source at any time*. If only one machine has ever produced a working artifact, the build process isn't trustworthy. Rebuilding from scratch on every push to `test` verifies that the build itself is deterministic.
- **prod** proves *we deploy only what has been tested*. Production gets a known-good image identifier — not a freshly built one. The act of promotion is auditable: every prod release maps to a specific `IMAGE_VERSION` value.

### How three deployments coexist on one EC2

All three branches deploy to the same EC2 host. Isolation is achieved at four layers:

| Layer | dev | test | prod |
|---|---|---|---|
| Compose project name (`-p`) | `bookshop-dev` | `bookshop-test` | `bookshop-prod` |
| Host port mapping | `8080:80` | `8081:80` | `80:80` |
| `.env` file path on EC2 | `/opt/bookshop/dev/.env` | `/opt/bookshop/test/.env` | `/opt/bookshop/prod/.env` |
| Compose file directory | `/opt/bookshop/dev/` | `/opt/bookshop/test/` | `/opt/bookshop/prod/` |

Distinct project names mean Docker treats each deployment as its own stack — containers, networks, and named volumes get a per-project prefix, so the three never share state. Distinct host ports mean three Nginx containers can listen simultaneously without colliding. Distinct directories and `.env` files mean each branch's secrets and compose configuration stay separate on disk.

### Compose automation (group of 3)

The assignment requires groups of three to automate the `docker-compose.yml` image-tag update — the file cannot be edited by hand. Our `docker-compose.yml` is committed once and never modified per deploy. The image reference is parameterised:

```yaml
services:
  backend:
    image: ${IMAGE_REPO}:${IMAGE_TAG}
```

At deploy time each workflow generates a `.env` file containing the correct `IMAGE_REPO` and `IMAGE_TAG` values for that branch, then `scp`s the `.env` next to the compose file on EC2. Docker Compose reads `.env` automatically and expands the variables.

We chose env-var substitution over the alternatives (sed-replace, committed templates, commit-back-to-repo) because docker-compose supports it natively, it requires no extra tooling on the runner or the EC2 host, it avoids polluting git history with deploy-time commits, and it keeps the single compose file as the canonical source — there are no diverging per-branch copies to maintain.

### Secrets and variables

Configured in **Settings → Secrets and variables → Actions**.

**Variables** (non-sensitive, visible in logs and UI):

- `IMAGE_VERSION` — the image tag currently deployed in production. The single source of truth for prod.
- `EC2_HOST` — public DNS of the EC2 instance.
- `ECR_REPOSITORY` — name of the ECR repository for our image.

**Secrets** (sensitive, masked in logs):

- `EC2_SSH_KEY` — private SSH key (Ed25519) for connecting to EC2.
- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` — IAM credentials for the ECR push/pull.
- `POSTGRES_PASSWORD`, `SECRET_KEY` — application-level secrets from Phase 1, injected into the container at runtime via the generated `.env`.

No secret is committed to the repo. The `.env` file on EC2 is generated by the workflow and never appears in git.

### How to trigger each pipeline

- **dev** — push or merge to the `dev` branch. The artifact appears in `artifacts/` and the container becomes reachable at `http://<EC2_HOST>:8080`.
- **test** — push or merge to the `test` branch. The image is pushed to ECR and the container becomes reachable at `http://<EC2_HOST>:8081`.
- **prod** — update the `IMAGE_VERSION` repository variable to the desired tag, then push or merge to `prod`. The container becomes reachable at `http://<EC2_HOST>` (port 80).

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
