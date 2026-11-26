# MySQL 8.4 LTS on Debian 13 (trixie) — Hardened Container Image

[![Daily MySQL 8.4 image](https://github.com/dgcosenza/mysql-docker/actions/workflows/daily.yml/badge.svg)](https://github.com/dgcosenza/mysql-docker/actions/workflows/daily.yml)
[![Packaging License: MIT](https://img.shields.io/badge/packaging-MIT-blue.svg)](https://github.com/dgcosenza/mysql-docker/blob/main/LICENSE)
[![Upstream License: GPL-2.0-only](https://img.shields.io/badge/upstream-GPL--2.0--only-green.svg)](https://github.com/mysql/mysql-server/blob/trunk/LICENSE)
[![Signed with Cosign](https://img.shields.io/badge/signed-cosign%20OIDC-blueviolet.svg)](#supply-chain-verification)
[![SLSA Level 3](https://img.shields.io/badge/SLSA-Level%203-brightgreen.svg)](#supply-chain-verification)
[![Architecture](https://img.shields.io/badge/arch-amd64-informational.svg)](#supported-architectures)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/dgcosenza/mysql-docker/badge)](https://scorecard.dev/viewer/?uri=github.com/dgcosenza/mysql-docker)
[![Docker Pulls](https://img.shields.io/docker/pulls/dgcosenza/mysql)](https://hub.docker.com/r/dgcosenza/mysql)
[![Docker Image Size](https://img.shields.io/docker/image-size/dgcosenza/mysql/8.4)](https://hub.docker.com/r/dgcosenza/mysql)
[![Latest Release](https://img.shields.io/github/v/release/dgcosenza/mysql-docker?label=version)](https://github.com/dgcosenza/mysql-docker/releases)

A hardened, rootless **MySQL 8.4 LTS Community Server** container image on **Debian 13 (`trixie-slim`)**, installing server and client packages from Oracle's official GPG-verified Debian 13 APT repository and compiling `gosu` from source with the latest patched Go toolchain, maintained by **Daniel G. Cosenza from FNX Labs**.

- **Docker Hub:** [`dgcosenza/mysql`](https://hub.docker.com/r/dgcosenza/mysql)
- **GitHub Container Registry (GHCR):** [`ghcr.io/dgcosenza/mysql`](https://github.com/dgcosenza/mysql-docker/pkgs/container/mysql) (identical signed digest)
- **Source Repository:** [`dgcosenza/mysql-docker`](https://github.com/dgcosenza/mysql-docker)
- **Upstream Application:** [MySQL Community Server](https://dev.mysql.com/) (`GPL-2.0-only`)

---

## Current Versions

<!-- versions:start -->
| Component | Resolved Version |
| --- | --- |
| MySQL Community Server (LTS) | `8.4.13 (8.4.13.1-1debian13)` |
| Step-down Helper | `gosu 1.20 (Go 1.27.4)` |
| Base OS | `Debian 13.8 (trixie-slim)` |
| Architectures | `linux/amd64` |
| Uncompressed size (per arch) | `amd64: 124.1 MB` |
| Last verified build (UTC) | `2026-11-26` |
| Published multi-arch digest | `dgcosenza/mysql@sha256:e4ee82a7df74c12c524527f35510eecbbe5d4af3234fb2a86343f3684407224c` |
| GHCR mirror | `ghcr.io/dgcosenza/mysql@sha256:e4ee82a7df74c12c524527f35510eecbbe5d4af3234fb2a86343f3684407224c` |
| Supply chain | Cosign OIDC signed + SPDX & CycloneDX SBOM attestations + SLSA Build L3 provenance |
| Security gate (Trivy + Grype on SBOM) | **0 fixable findings of any severity** (14 upstream-unfixed) |

**Recent upstream changes:**
- **MySQL 8.4:** `8.4.13` (`8.4.13.1-1debian13`) -> `8.4.13` (`8.4.13.1-1debian13`)
- **gosu:** `1.20` -> `1.20`
- **Go toolchain (gosu builder):** `1.27.4` -> `1.27.4`
- **Upstream version changed:** `no`
- Official Oracle MySQL 8.4.13 LTS Debian 13 package (`8.4.13.1-1debian13`). Release notes: https://dev.mysql.com/doc/relnotes/mysql/8.4/en/news-8-4-13.html
<!-- versions:end -->

---

## Supported Tags & Tag Policy

Identical OCI digests are published to **Docker Hub** (`dgcosenza/mysql`) and **GHCR** (`ghcr.io/dgcosenza/mysql`), accompanied by an automated signed [GitHub Release](https://github.com/dgcosenza/mysql-docker/releases):

| Tag | Policy | Description |
| --- | --- | --- |
| `8.4.x-<YYYYMMDD>` (e.g. `8.4.13-20261125`) | **Immutable** | Date-stamped daily rebuild pinning the MySQL 8.4 LTS patch release and UTC build date. |
| `sha-<short>` | **Immutable** | Packaging repository Git commit tag. |
| `8.4.x` (e.g. `8.4.13`) | Moving | Latest verified Debian 13 security rebuild of that MySQL patch release. |
| `8.4`, `latest` | Moving | Latest verified daily MySQL 8.4 LTS build. |

**Production pinning:** Pin by immutable registry digest rather than an unpinned moving tag:

```yaml
image: dgcosenza/mysql:8.4@sha256:<digest>
# or via GitHub Container Registry (identical digest):
image: ghcr.io/dgcosenza/mysql:8.4@sha256:<digest>
```

---

## Supported Architectures

| Architecture | Status | Verification |
| --- | --- | --- |
| `linux/amd64` | **Published & natively tested** | Built, smoke-tested (UID `999`, initdb, CRUD, `mysqldump`, negative healthcheck), Dive-gated, Syft/Trivy/Grype-scanned, and Cosign-signed on native x86_64 CI runners. |
| `linux/arm64` | **Not shipped upstream** | Oracle's official Debian 13 (`trixie`) APT repository (`repo.mysql.com/apt/debian/dists/trixie/Release`) publishes `amd64` packages only. `arm64` will be enabled automatically if Oracle adds `arm64` Debian 13 binaries. |

---

## Quick Start

### Docker CLI (hardened, rootless)

```bash
docker run -d --name mysql84 \
  --read-only \
  --cap-drop ALL \
  --cap-add SYS_NICE \
  --security-opt no-new-privileges:true \
  --tmpfs /var/run/mysqld:uid=999,gid=999,mode=1777,size=16m \
  --tmpfs /tmp:mode=1777,size=128m \
  -e MYSQL_ROOT_PASSWORD=change_me_root \
  -e MYSQL_DATABASE=myapp \
  -e MYSQL_USER=myapp \
  -e MYSQL_PASSWORD=change_me_user \
  -v mysql_data:/var/lib/mysql \
  -p 127.0.0.1:3306:3306 \
  dgcosenza/mysql:8.4
```

### Hardened Docker Compose

See [`docker-compose.example.yml`](https://github.com/dgcosenza/mysql-docker/blob/main/docker-compose.example.yml):

```yaml
services:
  mysql:
    image: dgcosenza/mysql:8.4
    restart: unless-stopped
    read_only: true
    cap_drop:
      - ALL
    cap_add:
      - SYS_NICE
    security_opt:
      - no-new-privileges:true
    tmpfs:
      - /var/run/mysqld:uid=999,gid=999,mode=1777,size=16m
      - /tmp:mode=1777,size=128m
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

---

## Configuration

### Environment Variables

Full drop-in compatibility with the official `docker-library/mysql:8.4` entrypoint:

| Variable | Description | Required |
| --- | --- | --- |
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

### Volumes, Ports, and UID/GID

| Path / Port | Mode / Owner | Purpose |
| --- | --- | --- |
| `/var/lib/mysql` | `999:999` (`mysql`) | Persistent database data directory |
| `/docker-entrypoint-initdb.d` | Read-only | First-start initialization scripts (`*.sh`, `*.sql`, `*.sql.{gz,xz,zst,bz2}`) |
| `/etc/mysql/conf.d` | Read-only | Custom `.cnf` server overrides |
| `3306/tcp`, `33060/tcp` | Internal | Classic MySQL and X Protocol ports |

Runs as non-root **`mysql:mysql` (UID/GID `999:999`)** by default, compatible with `read_only: true`, `cap_drop: [ALL]` (optional `cap_add: [SYS_NICE]` for InnoDB thread priority), and `no-new-privileges:true`.

---

## Healthcheck

`healthcheck.sh` verifies that `/var/run/mysqld/mysqld.sock` is live and executes `SELECT 1;` over the Unix socket when `MYSQL_ROOT_PASSWORD` (or `MYSQL_ROOT_PASSWORD_FILE`) is available.

---

## Upgrade and Migration from Upstream `mysql:8.4`

This image is data-directory compatible with upstream `mysql:8.4`:

1. **Take a verified dump first:** Run `mysqldump --all-databases --single-transaction --routines --triggers` before switching.
2. **Stay on the 8.4 LTS series:** Never downgrade a MySQL 8.4 data directory to 8.0 or jump to 9.x unintentionally.
3. **Preserve your data volume:** Never run `docker compose down -v`. Recreate only the database service (`docker compose up -d --no-deps <service>`).
4. **Keep a rollback tag:** Tag the outgoing image locally before switching to `dgcosenza/mysql:8.4@sha256:<digest>` (or GHCR).

---

## Supply-Chain Verification

Every published digest on both Docker Hub and GHCR is keyless-signed with **Sigstore Cosign** (GitHub OIDC), attested with **SPDX** and **CycloneDX** SBOMs, and backed by **SLSA Build L3** provenance (`actions/attest-build-provenance`).

### Verify image signature with Cosign

```bash
cosign verify \
  --certificate-identity-regexp="^https://github\.com/dgcosenza/mysql-docker/\.github/workflows/daily\.yml@refs/heads/main$" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  ghcr.io/dgcosenza/mysql:8.4

# Or against Docker Hub (identical digest):
cosign verify \
  --certificate-identity-regexp="^https://github\.com/dgcosenza/mysql-docker/\.github/workflows/daily\.yml@refs/heads/main$" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  dgcosenza/mysql:8.4
```

### Verify SPDX / CycloneDX SBOM attestations

```bash
cosign verify-attestation \
  --type spdxjson \
  --certificate-identity-regexp="^https://github\.com/dgcosenza/mysql-docker/\.github/workflows/daily\.yml@refs/heads/main$" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  ghcr.io/dgcosenza/mysql@sha256:<digest>
```

### Verify SLSA Build Provenance

```bash
gh attestation verify oci://ghcr.io/dgcosenza/mysql:8.4 --owner dgcosenza
```

---

## Security

- **Preflight gates:** Every push and PR runs **Hadolint** (blocking on warning+), **Gitleaks** secret scanning across git history, and **public-content/attribution** checks.
- **Vulnerability scan policy (all severities with a fix):** Every build generates **SPDX** and **CycloneDX** SBOMs with **Syft**, scans with **Trivy** (table, JSON, SARIF upload, blocking `--ignore-unfixed` gate) and **Grype** scanning the SPDX SBOM (`--only-fixed --fail-on negligible`), and enforces a **Dive** efficiency gate (`>= 95%`, `<= 5%` wasted user bytes).
- **Current status:** **0 fixable vulnerabilities of any severity** across Debian 13 OS packages, MySQL 8.4 LTS, and source-built `gosu`.
- **Dependency automation:** Renovate (`renovate.json`) pins base image digests and GitHub Action commit SHAs; Dependabot security alerts and OpenSSF Scorecard monitoring are enabled.
- See [`SECURITY.md`](https://github.com/dgcosenza/mysql-docker/blob/main/SECURITY.md) for responsible disclosure.

---

## Build Locally

```bash
docker buildx build --platform linux/amd64 --load \
  --build-arg MYSQL_DEB_VERSION=8.4.13.1-1debian13 \
  --build-arg MYSQL_UPSTREAM_VERSION=8.4.13 \
  -t dgcosenza/mysql:8.4-local .
```

---

## Update Policy

[`.github/workflows/daily.yml`](https://github.com/dgcosenza/mysql-docker/blob/main/.github/workflows/daily.yml) runs automatically every day at **04:47 UTC**, on pushes to `main`, on pull requests (verification only), and via `workflow_dispatch`:

1. **Preflight & upstream check:** Runs public-content checks, **Hadolint**, and **Gitleaks**; queries Oracle's Debian 13 MySQL 8.4 LTS APT index (`repo.mysql.com`), `tianon/gosu`, `go.dev`, and Docker Hub for digest-pinned base images, emitting `upstream-changes.md`.
2. **No-cache rebuild:** Rebuilds on `debian:trixie-slim` with `--no-cache` on schedule, running `apt-get upgrade` and compiling `gosu` from source with the latest patched Go release.
3. **Smoke, Dive & vulnerability gates:** Runs [`tests/smoke.sh`](https://github.com/dgcosenza/mysql-docker/blob/main/tests/smoke.sh), enforces the **Dive** efficiency gate (`>= 95%`, `<= 5%` wasted), generates **Syft** SPDX + CycloneDX SBOMs, and gates publication on **0 fixable findings of any severity** in both **Trivy** and **Grype** (scanning the SPDX SBOM).
4. **Dual-registry publish & supply-chain signing:** Publishes the identical digest to **GHCR** (`ghcr.io/dgcosenza/mysql`) and **Docker Hub** (`dgcosenza/mysql`) with tags `latest`, `8.4`, `<version>`, `<version>-<YYYYMMDD>`, and `sha-<short>`; signs and attests SPDX/CycloneDX SBOMs via **Cosign** keyless OIDC; emits **SLSA Build L3** provenance; and publishes a signed **GitHub Release** with checksums and SBOMs.
5. **Automated documentation sync:** Commits updated `versions.json`, the README `Current Versions` block, and a dated `CHANGELOG.md` entry via `github-actions[bot]` (`[skip ci]`, validated by `public-check.sh`), then syncs the Docker Hub overview and short description.
6. **Failure alerting:** Opens or updates a single GitHub issue labeled `ci-failure` on any `main` or scheduled failure, and auto-closes it on the next green run.

---

## Design Decisions

- **Debian 13 (`trixie-slim`) + official Oracle MySQL APT repo:** Upstream `mysql:8.4` is based on Oracle Linux 9 (`oraclelinux:9-slim`), which carries dozens of stale RPM vulnerabilities and bundles `mysql-shell` (with Python libraries). Building on Debian 13 (`trixie-slim`) using Oracle's signed `mysql-8.4-lts` Debian 13 repository (`BCA43417C3B485DD128EC6D4B7B3B788A8D3785C`) eliminates those CVEs while preserving binary-identical MySQL 8.4 LTS storage compatibility.
- **`linux/amd64` only:** Oracle's official Debian 13 APT feed (`repo.mysql.com/apt/debian/dists/trixie/Release`) currently ships `Architectures: amd64` only.
- **Source-rebuilt `gosu`:** Compiling `gosu` with the latest Go release eliminates Go stdlib CVEs found in prebuilt binaries.
- **Hadolint `DL3008` ignore:** Daily `--no-cache` security rebuilds intentionally pull the newest Debian 13 security updates via `apt-get`.

---

## License

This repository follows a clear packaging-vs-upstream license split:

- **Container packaging, healthcheck script, CI workflows, and documentation (`packaging: MIT`):** Licensed under the [MIT License](https://github.com/dgcosenza/mysql-docker/blob/main/LICENSE) — copyright **Daniel G. Cosenza from FNX Labs**.
- **Bundled upstream software — MySQL Community Server 8.4 LTS (`upstream: GPL-2.0-only`):** Copyright Oracle and/or its affiliates — licensed under the [GNU General Public License v2.0](https://github.com/mysql/mysql-server/blob/trunk/LICENSE).

Full third-party notices are maintained in [`THIRD-PARTY-NOTICES.md`](https://github.com/dgcosenza/mysql-docker/blob/main/THIRD-PARTY-NOTICES.md). Release history is maintained in [`CHANGELOG.md`](https://github.com/dgcosenza/mysql-docker/blob/main/CHANGELOG.md).

## Credits

- [Oracle MySQL Community Server](https://dev.mysql.com/)
- [docker-library/mysql](https://github.com/docker-library/mysql)
- [tianon/gosu](https://github.com/tianon/gosu)
- [Debian Project](https://www.debian.org/)

Maintained by **Daniel G. Cosenza from FNX Labs**.
