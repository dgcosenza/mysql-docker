# syntax=docker/dockerfile:1.7
# Hardened MySQL 8.4 LTS on Debian 13 (trixie)
# Upstream: https://dev.mysql.com/ / https://github.com/docker-library/mysql
# Maintainer: Daniel G. Cosenza from FNX Labs

ARG DEBIAN_VERSION=trixie-slim
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
FROM golang:${GO_VERSION}-trixie AS gosu-builder

ARG GOSU_VERSION
ARG TARGETOS=linux
ARG TARGETARCH

RUN set -eux; \
    git clone --depth 1 --branch "${GOSU_VERSION}" https://github.com/tianon/gosu.git /src/gosu; \
    cd /src/gosu; \
    CGO_ENABLED=0 GOOS="${TARGETOS}" GOARCH="${TARGETARCH}" \
        go build -trimpath -ldflags="-s -w" -o /out/gosu .; \
    go test ./...

# ---- Stage 2: Runtime image ----
FROM debian:${DEBIAN_VERSION} AS runtime

ARG DEBIAN_VERSION
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
      org.opencontainers.image.licenses="GPL-2.0-only" \
      org.opencontainers.image.base.name="docker.io/library/debian:${DEBIAN_VERSION}" \
      io.github.dgcosenza.mysql.major="${MYSQL_MAJOR}" \
      io.github.dgcosenza.mysql.version="${MYSQL_UPSTREAM_VERSION}" \
      io.github.dgcosenza.mysql.deb_version="${MYSQL_DEB_VERSION}" \
      io.github.dgcosenza.mysql.gosu="${GOSU_VERSION}" \
      io.github.dgcosenza.mysql.go="${GO_VERSION}"

# Create mysql user/group with consistent UID/GID 999 (docker-library convention)
RUN groupadd --system --gid 999 mysql \
    && useradd --system --uid 999 --gid 999 --home-dir /var/lib/mysql --no-create-home --shell /bin/bash mysql

COPY --from=gosu-builder /out/gosu /usr/local/bin/gosu
RUN chmod 0755 /usr/local/bin/gosu && gosu --version && gosu nobody true

# Upgrade base OS, verify MySQL APT signing key, and install MySQL 8.4 LTS Community Server
RUN set -eux; \
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
    [ -z "${savedAptMark}" ] || apt-mark manual ${savedAptMark} mysql-community-server mysql-community-client > /dev/null; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false curl gpg; \
    rm -rf /var/lib/apt/lists/*; \
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

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod 0755 /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

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
