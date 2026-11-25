# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

Maintained by **Daniel G. Cosenza from FNX Labs**.

## [Unreleased]

<!-- changelog:auto -->

## [8.4.13] — 2026-11-25

### Automated Daily Build
- Verified components: MySQL Community Server (LTS) `8.4.13 (8.4.13.1-1debian13)`, Step-down Helper `gosu 1.20 (Go 1.27.4)`, Base OS `Debian 13.8 (trixie-slim)`.
- Architectures verified: `linux/amd64` (native smoke tests + Dive efficiency gate).
- Upstream changes:
  - **MySQL 8.4:** `8.4.13` (`8.4.13.1-1debian13`) -> `8.4.13` (`8.4.13.1-1debian13`)
  - **gosu:** `1.20` -> `1.20`
  - **Go toolchain (gosu builder):** `1.27.4` -> `1.27.4`
  - **Upstream version changed:** `no`
  - Official Oracle MySQL 8.4.13 LTS Debian 13 package (`8.4.13.1-1debian13`). Release notes: https://dev.mysql.com/doc/relnotes/mysql/8.4/en/news-8-4-13.html
- Vulnerability gate: **0 fixable Critical/High** in Trivy and Grype (SBOM scan) (14 upstream-unfixed).
- Published multi-arch digest (Docker Hub + GHCR): `dgcosenza/mysql@sha256:45c4ac066cef703807756182becd81e07c597b1de585569ac8400d944e76425a` (Cosign OIDC signed + SPDX/CycloneDX SBOM + SLSA L3 provenance).
---

---

## [2026-11-25]

### Changed
- Rebuilt MySQL `8.4.13` (`8.4.13.1-1debian13`) on Debian `13.8` (`dgcosenza/mysql@sha256:4110eecff23a06a710eb409f1e9d9ea1ac5106d0d965505368089d64323845f3`)

### Security
- Trivy and Grype gates verified: 0 fixable Critical/High vulnerabilities.

## [2026-11-24]

### Added
- Initial hardened MySQL 8.4 LTS (`8.4.13.1-1debian13`) image on Debian 13 (`trixie-slim`) using Oracle's official GPG-verified Debian 13 MySQL 8.4 LTS APT repository.
- Source-rebuilt `gosu 1.20` using Go `1.27.4` (`golang:1.27.4-trixie`).
- Built-in `healthcheck.sh`, full `docker-library/mysql` entrypoint parity, non-root `mysql` (UID/GID `999:999`) default user, and full 7-step automated daily CI pipeline.

### Security
- Eliminated 92 fixable vulnerabilities (2 Critical, 90 High) present in the upstream Oracle Linux 9 `mysql:8.4` image.
- Verified 0 fixable Critical/High findings in both Trivy and Grype.
