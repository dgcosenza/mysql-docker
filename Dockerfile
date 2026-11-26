# syntax=docker/dockerfile:1.7
# Hardened MySQL 8.4 LTS on Debian 13 (trixie)
# Upstream: https://dev.mysql.com/ / https://github.com/docker-library/mysql
# Maintainer: Daniel G. Cosenza from FNX Labs

ARG GO_BASE=golang:1.27.4-trixie@sha256:430985542100b871e108ccc00e8dcc5eef08ca14ee5825e98ebf563d8ffec4ee
ARG DEBIAN_BASE=debian:trixie-slim@sha256:8aa5a7bf5a1955bddbe7d74fcdd0b91ab30e74362a8b73af672b0481b35b44a0
ARG MYSQL_MAJOR=8.4
ARG MYSQL_DEB_VERSION=8.4.13.1-1debian13
ARG MYSQL_UPSTREAM_VERSION=8.4.13
ARG GOSU_VERSION=1.20
ARG GO_VERSION=1.27.4
# MySQL Release Engineering <mysql-build@oss.oracle.com> (expires 2027-10-23)
ARG MYSQL_GPG_FPR=BCA43417C3B485DD128EC6D4B7B3B788A8D3785C
ARG IMAGE_CREATED=1970-01-01T00:00:00Z
ARG IMAGE_REVISION=dev
ARG IMAGE_SOURCE=https://github.com/dgcosenza/mysql-docker

# ---- Stage 1: Build gosu from source with the latest patched Go toolchain ----
FROM ${GO_BASE} AS gosu-builder

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG GOSU_VERSION
ARG TARGETOS=linux
ARG TARGETARCH=amd64

WORKDIR /src
RUN git clone --depth 1 --branch "${GOSU_VERSION}" https://github.com/tianon/gosu.git /src/gosu

WORKDIR /src/gosu
# Patch the indirect golang.org/x/sys dependency (fixable CVE-2026-39824).
RUN go get golang.org/x/sys@v0.50.0
RUN set -eux; \
    CGO_ENABLED=0 GOOS="${TARGETOS}" GOARCH="${TARGETARCH}" \
        go build -trimpath -ldflags="-s -w" -o /out/gosu .; \
    go test ./...

# ---- Stage 2: Runtime image ----
FROM ${DEBIAN_BASE} AS runtime

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG MYSQL_MAJOR
ARG MYSQL_DEB_VERSION
ARG MYSQL_UPSTREAM_VERSION
ARG GOSU_VERSION
ARG GO_VERSION
ARG MYSQL_GPG_FPR
ARG IMAGE_CREATED
ARG IMAGE_REVISION
ARG IMAGE_SOURCE
ARG DEBIAN_FRONTEND=noninteractive

LABEL org.opencontainers.image.title="MySQL 8.4 LTS on Debian 13 (trixie)" \
      org.opencontainers.image.description="Hardened MySQL 8.4 LTS Community Server container image on Debian 13 (trixie-slim) from the official MySQL APT repository, maintained by Daniel G. Cosenza from FNX Labs." \
      org.opencontainers.image.version="${MYSQL_UPSTREAM_VERSION}" \
      org.opencontainers.image.revision="${IMAGE_REVISION}" \
      org.opencontainers.image.created="${IMAGE_CREATED}" \
      org.opencontainers.image.url="https://hub.docker.com/r/dgcosenza/mysql" \
      org.opencontainers.image.source="${IMAGE_SOURCE}" \
      org.opencontainers.image.documentation="${IMAGE_SOURCE}#readme" \
      org.opencontainers.image.vendor="Daniel G. Cosenza from FNX Labs" \
      org.opencontainers.image.authors="Daniel G. Cosenza from FNX Labs" \
      org.opencontainers.image.licenses="GPL-2.0-only AND MIT" \
      org.opencontainers.image.base.name="debian:trixie-slim" \
      io.github.dgcosenza.mysql.major="${MYSQL_MAJOR}" \
      io.github.dgcosenza.mysql.version="${MYSQL_UPSTREAM_VERSION}" \
      io.github.dgcosenza.mysql.deb_version="${MYSQL_DEB_VERSION}" \
      io.github.dgcosenza.mysql.gosu="${GOSU_VERSION}" \
      io.github.dgcosenza.mysql.go="${GO_VERSION}"

COPY --from=gosu-builder --chmod=0755 /out/gosu /usr/local/bin/gosu

# Create mysql user, upgrade base OS, verify MySQL APT key, and install MySQL 8.4 LTS
RUN set -eux; \
    groupadd --system --gid 999 mysql; \
    useradd --system --uid 999 --gid 999 --home-dir /var/lib/mysql --no-create-home --shell /bin/bash mysql; \
    gosu --version; \
    gosu nobody true; \
    apt-get update; \
    apt-get -y upgrade; \
    apt-get install -y --no-install-recommends \
        bzip2 \
        ca-certificates \
        findutils \
        gpgv \
        gzip \
        openssl \
        tzdata \
        xz-utils \
        zstd; \
    savedAptMark="$(apt-mark showmanual)"; \
    apt-get install -y --no-install-recommends curl gpg; \
    \
    install -d -m 0755 /etc/apt/keyrings; \
    KEY_TMP="$(mktemp)"; \
    curl -fsSL "https://repo.mysql.com/RPM-GPG-KEY-mysql-2025" -o "${KEY_TMP}"; \
    FPR="$(gpg --show-keys --with-colons "${KEY_TMP}" | awk -F: '/^fpr:/ { print $10; exit }')"; \
    if [ "${FPR}" != "${MYSQL_GPG_FPR}" ]; then \
        echo "ERROR: MySQL GPG key fingerprint mismatch: got ${FPR}, expected ${MYSQL_GPG_FPR}" >&2; \
        exit 1; \
    fi; \
    gpg --batch --dearmor -o /etc/apt/keyrings/mysql.gpg "${KEY_TMP}"; \
    chmod 0644 /etc/apt/keyrings/mysql.gpg; \
    rm -f "${KEY_TMP}"; \
    \
    echo "deb [signed-by=/etc/apt/keyrings/mysql.gpg] https://repo.mysql.com/apt/debian/ trixie mysql-${MYSQL_MAJOR}-lts" \
        > /etc/apt/sources.list.d/mysql.list; \
    \
    apt-get update; \
    { \
        echo "mysql-community-server mysql-community-server/data-dir select ''"; \
        echo "mysql-community-server mysql-community-server/root-pass password ''"; \
        echo "mysql-community-server mysql-community-server/re-root-pass password ''"; \
        echo "mysql-community-server mysql-community-server/remove-test-db select false"; \
    } | debconf-set-selections; \
    apt-get install -y --no-install-recommends \
        "mysql-community-server=${MYSQL_DEB_VERSION}" \
        "mysql-community-client=${MYSQL_DEB_VERSION}"; \
    \
    apt-mark auto '.*' > /dev/null; \
    printf '%s\n' "${savedAptMark}" | xargs -r apt-mark manual > /dev/null; \
    apt-mark manual mysql-community-server mysql-community-client > /dev/null; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false curl gpg; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*; \
    \
    # Reset postinst data directory and configure container-friendly paths \
    rm -rf /var/lib/mysql; \
    mkdir -p /var/lib/mysql /var/lib/mysql-files /var/lib/mysql-keyring /var/run/mysqld /etc/mysql/conf.d /docker-entrypoint-initdb.d; \
    chown -R mysql:mysql /var/lib/mysql /var/lib/mysql-files /var/lib/mysql-keyring /var/run/mysqld /etc/mysql/conf.d /docker-entrypoint-initdb.d; \
    chmod 1777 /var/lib/mysql /var/run/mysqld; \
    \
    # Ensure mysqld listens on container network interfaces and uses /var/run/mysqld/mysqld.sock \
    find /etc/mysql/ -name '*.cnf' -print0 \
        | xargs -0 grep -lZE '^(bind-address|mysqlx-bind-address|log-error|user\s)' \
        | xargs -rt -0 sed -Ei 's/^(bind-address|mysqlx-bind-address|log-error|user\s)/#&/'; \
    printf "[mysqld]\npid-file = /var/run/mysqld/mysqld.pid\nsocket = /var/run/mysqld/mysqld.sock\ndatadir = /var/lib/mysql\nsecure-file-priv = /var/lib/mysql-files\nhost-cache-size = 0\n\n[client]\nsocket = /var/run/mysqld/mysqld.sock\n" \
        > /etc/mysql/mysql.conf.d/99-container.cnf; \
    \
    mysqld --version; \
    mysql --version; \
    mysqldump --version

COPY --chmod=0755 docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY --chmod=0755 healthcheck.sh /usr/local/bin/healthcheck.sh

ENV LANG=C.UTF-8 \
    GOSU_VERSION="${GOSU_VERSION}" \
    MYSQL_MAJOR="${MYSQL_MAJOR}" \
    MYSQL_VERSION="${MYSQL_DEB_VERSION}"

VOLUME /var/lib/mysql

EXPOSE 3306 33060

USER mysql:mysql

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["mysqld"]

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD ["healthcheck.sh"]
