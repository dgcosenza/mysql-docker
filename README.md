# MySQL 8.4 LTS on Debian 13 (trixie) — Hardened Container Image

[![CI](https://github.com/dgcosenza/mysql-docker/actions/workflows/daily.yml/badge.svg)](https://github.com/dgcosenza/mysql-docker/actions/workflows/daily.yml)
[![Docker Hub Pulls](https://img.shields.io/docker/pulls/dgcosenza/mysql?label=docker%20pulls)](https://hub.docker.com/r/dgcosenza/mysql)
[![Image Size](https://img.shields.io/docker/image-size/dgcosenza/mysql/8.4?label=image%20size)](https://hub.docker.com/r/dgcosenza/mysql)
[![License](https://img.shields.io/github/license/dgcosenza/mysql-docker)](LICENSE)

A hardened, continuously rebuilt **MySQL 8.4 LTS Community Server** container image on **Debian 13 (`trixie-slim`)**, installing server and client packages from the official GPG-verified Oracle MySQL Debian 13 APT repository and compiling `gosu` from source with the latest patched Go toolchain.

Maintained by **Daniel G. Cosenza from FNX Labs**.

## Current Versions

<!-- versions:start -->
_Last verified build: **2026-11-24** (UTC)_

| Component | Resolved Version |
|-----------|------------------|
| MySQL Community Server (LTS) | `8.4.13` (`8.4.13.1-1debian13`) |
| Base OS | Debian `13` (`debian:trixie-slim`) |
| Step-down Helper | `gosu 1.20` (built with Go `1.27.4`) |
| Fixable Critical/High (Trivy / Grype) | `0` / `0` |

**Recent upstream updates:**
- Initial hardened Debian 13 release for MySQL 8.4 LTS.
<!-- versions:end -->

## Supported Tags

| Tag | Description |
|-----|-------------|
| `latest`, `8.4` | Moving tags tracking the newest verified daily MySQL 8.4 LTS build |
| `8.4.x` | Latest build for a specific upstream MySQL 8.4 patch release (e.g. `8.4.13`) |
| `8.4.x-YYYYMMDD` | Immutable date-stamped build (e.g. `8.4.13-20261124`) |
| `sha-<short>` | Immutable commit-stamped build |

## Quick Start

### Docker CLI

```bash
docker run -d --name mysql84 \
  --security-opt no-new-privileges:true \
  -e MYSQL_ROOT_PASSWORD=change_me_root \
  -e MYSQL_DATABASE=myapp \
  -e MYSQL_USER=myapp \
  -e MYSQL_PASSWORD=change_me_user \
  -v mysql_data:/var/lib/mysql \
  -p 127.0.0.1:3306:3306 \
  dgcosenza/mysql:8.4
```

### Docker Compose

```yaml
services:
  mysql:
    image: dgcosenza/mysql:8.4
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    cap_add:
      - SYS_NICE
    environment:
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
      - MYSQL_DATABASE=myapp
      - MYSQL_USER=myapp
      - MYSQL_PASSWORD=${MYSQL_PASSWORD}
    volumes:
      - mysql_data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "healthcheck.sh"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s

volumes:
  mysql_data:
```

See [docker-compose.example.yml](docker-compose.example.yml) for a complete production-ready configuration.

## Configuration

### Environment Variables

Full drop-in compatibility with the official `docker-library/mysql:8.4` entrypoint:

| Variable | Description | Required |
|----------|-------------|----------|
| `MYSQL_ROOT_PASSWORD` | Password for `root` (or `MYSQL_ROOT_PASSWORD_FILE` for Docker secrets) | Yes¹ |
| `MYSQL_ALLOW_EMPTY_PASSWORD` | Allow empty root password (development only) | No |
| `MYSQL_RANDOM_ROOT_PASSWORD` | Generate a random root password printed to logs | No |
| `MYSQL_DATABASE` | Database created on first initialization | No |
| `MYSQL_USER` | Application user created on first initialization | No |
| `MYSQL_PASSWORD` | Password for `MYSQL_USER` (or `MYSQL_PASSWORD_FILE`) | No² |
| `MYSQL_ROOT_HOST` | Host pattern allowed for `root` (default: `%`) | No |
| `MYSQL_ONETIME_PASSWORD` | Force root password change on first login | No |
| `MYSQL_INITDB_SKIP_TZINFO` | Skip loading timezone tables during init | No |

¹ Required on first initialization unless `MYSQL_ALLOW_EMPTY_PASSWORD` or `MYSQL_RANDOM_ROOT_PASSWORD` is set.  
² Required if `MYSQL_USER` is set.

### Volumes

| Path | Purpose |
|------|---------|
| `/var/lib/mysql` | Persistent database data directory (UID/GID `999:999`) |
| `/docker-entrypoint-initdb.d` | Initialization scripts run once on an empty data directory (`*.sh`, `*.sql`, `*.sql.gz`, `*.sql.xz`, `*.sql.zst`, `*.sql.bz2`) |
| `/etc/mysql/conf.d` | Custom `.cnf` server overrides |

### Ports

- `3306/tcp` — Classic MySQL protocol
- `33060/tcp` — MySQL X Protocol

### User, UID, and GID

- Runs as non-root `mysql:mysql` (**UID 999 / GID 999**) by default, matching upstream `mysql:8.4`.
- If started with `--user 0` against a root-owned host bind mount, `docker-entrypoint.sh` fixes ownership and immediately steps down to `mysql` via the source-rebuilt `gosu`.

### Healthcheck

The built-in `healthcheck.sh` verifies that `/var/run/mysqld/mysqld.sock` is live and executes `SELECT 1;` over the Unix socket when `MYSQL_ROOT_PASSWORD` (or `MYSQL_ROOT_PASSWORD_FILE`) is available.

## Upgrade and Migration from Upstream `mysql:8.4`

This image is data-directory compatible with upstream `mysql:8.4`:

1. **Take a verified dump first:** Run `mysqldump --all-databases --single-transaction --routines --triggers` before switching.
2. **Stay on the 8.4 LTS series:** Never downgrade a MySQL 8.4 data directory to 8.0 or jump to 9.x unintentionally.
3. **Preserve your data volume:** Never run `docker compose down -v` or drop existing volumes. Recreate only the database service (`docker compose up -d <service>`).
4. **UID/GID parity:** Existing `mysql:8.4` volumes are already owned by `999:999`, so non-root startup works immediately.
5. **Keep a rollback tag:** Tag the outgoing image locally before switching so you can revert cleanly if required.

## Security

- **Trivy** (OS + libraries): SARIF uploaded to GitHub Code Scanning; table and JSON reports retained for 90 days; **blocking hard gate** on any fixable `CRITICAL` or `HIGH` vulnerability.
- **Grype**: **blocking hard gate** (`--only-fixed`, severity cutoff `high`) with table report retained for 90 days.
- **SBOM & Provenance**: SPDX-JSON SBOM (Syft) and build provenance JSON retained for 90 days.
- **Unfixable findings**: None currently at Critical/High; any future upstream-unfixed findings are tracked in daily artifacts.

See [SECURITY.md](SECURITY.md) for responsible disclosure.

## Build Locally

```bash
docker buildx build --platform linux/amd64 --load \
  --build-arg MYSQL_DEB_VERSION=8.4.13.1-1debian13 \
  --build-arg MYSQL_UPSTREAM_VERSION=8.4.13 \
  -t dgcosenza/mysql:8.4-local .
```

## Update Policy

Every day at **04:47 UTC** (and on push to `main`, pull requests, or manual dispatch), `.github/workflows/daily.yml` runs a fully automated 7-step pipeline gated by `.github/scripts/public-check.sh`:

1. **Upstream check:** Queries Oracle's official Debian 13 MySQL 8.4 LTS APT index (`repo.mysql.com`), `tianon/gosu`, and `go.dev` to resolve the latest official package and Go toolchain, diffs against `versions.json`, and saves `upstream-changes.md` as a 90-day artifact.
2. **Clean rebuild:** Rebuilds on `debian:trixie-slim` with `--no-cache` on scheduled runs, running `apt-get upgrade` and compiling `gosu` from source, then generates an SPDX-JSON SBOM and provenance record.
3. **Vulnerability fix & hard gates:** Runs Trivy (table, JSON, SARIF upload, and blocking 0 fixable `CRITICAL`/`HIGH` gate) and Grype (blocking 0 fixable `CRITICAL`/`HIGH` gate), retaining all reports for 90 days and diffing newly fixed CVEs.
4. **Functional smoke test:** Executes `tests/smoke.sh` to verify healthy startup, UID 999 non-root execution, MySQL 8.4 version, `/docker-entrypoint-initdb.d`, SQL CRUD, `mysqldump`, and negative healthcheck failure.
5. **Registry publish:** On non-PR runs when Docker Hub credentials are configured, pushes `latest`, `8.4`, `<version>`, `<version>-<YYYYMMDD>`, and `sha-<short>` tags and records the published digest.
6. **Automated documentation sync:** Updates `versions.json`, the `<!-- versions:start -->` block in `README.md`, and `CHANGELOG.md` via `github-actions[bot]` (`[skip ci]`, validated by `public-check.sh`) whenever metadata changes, then syncs the overview and short description to Docker Hub.
7. **Failure alerting:** Automatically opens or updates a single GitHub issue labeled `ci-failure` on any `main` or scheduled failure, and auto-closes it on the next green run.

## Design Decisions

- **Debian 13 (`trixie-slim`) + official Oracle MySQL APT repo:** Upstream `mysql:8.4` is based on Oracle Linux 9 (`oraclelinux:9-slim`), which frequently carries dozens of stale RPM vulnerabilities and bundles `mysql-shell` (with Python libraries). Building on Debian 13 (`trixie-slim`) using Oracle's official signed `mysql-8.4-lts` Debian 13 repository (key fingerprint `BCA43417C3B485DD128EC6D4B7B3B788A8D3785C`) eliminates those CVEs and shrinks the attack surface while preserving binary-identical MySQL 8.4 LTS storage compatibility.
- **Source-rebuilt `gosu`:** Compiling `gosu` with the latest Go release eliminates Go stdlib CVEs found in prebuilt binaries.
- **Omission of `mysql-shell`:** Keeps the runtime minimal and avoids pulling bundled Python runtimes; standard `/usr/bin/mysql`, `/usr/bin/mysqladmin`, and `/usr/bin/mysqldump` are included.
- **Direct `mysqld` PID 1 (`exec`):** Preserves graceful InnoDB shutdown on `SIGTERM`.

## License

- Repository build files, scripts, and documentation: **MIT License** — see [LICENSE](LICENSE).
- MySQL Community Server 8.4 LTS: **GPL-2.0-only** — see [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).

## Credits

- [Oracle MySQL Community Server](https://dev.mysql.com/)
- [docker-library/mysql](https://github.com/docker-library/mysql)
- [tianon/gosu](https://github.com/tianon/gosu)
- [Debian Project](https://www.debian.org/)

Maintained by **Daniel G. Cosenza from FNX Labs**.
