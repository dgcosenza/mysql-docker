#!/usr/bin/env bash
# Smoke test for dgcosenza/mysql image
# Verifies: startup, healthcheck, non-root UID 999, MySQL 8.4 version,
# /docker-entrypoint-initdb.d execution, CRUD, mysqldump, and negative healthcheck.

set -euo pipefail

IMAGE="${1:-dgcosenza/mysql:ci-candidate}"
CONTAINER_NAME="mysql-smoke-$$"
VOLUME_NAME="mysql-smoke-vol-$$"

echo "=== Smoke testing ${IMAGE} ==="

ROOT_PASSWORD="$(openssl rand -hex 24)"
USER_PASSWORD="$(openssl rand -hex 24)"
DATABASE="testdb"
USER="testuser"

TMPINIT="$(mktemp -d)"
cat > "${TMPINIT}/01-init.sql" <<'SQL'
CREATE TABLE IF NOT EXISTS init_marker (id INT PRIMARY KEY, note VARCHAR(64));
INSERT INTO init_marker (id, note) VALUES (1, 'initialized') ON DUPLICATE KEY UPDATE note='initialized';
SQL
chmod -R a+rX "${TMPINIT}"

cleanup() {
    docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
    docker volume rm -f "${VOLUME_NAME}" >/dev/null 2>&1 || true
    rm -rf "${TMPINIT}"
}
trap cleanup EXIT

docker volume create "${VOLUME_NAME}" >/dev/null

echo "Starting container (default non-root user)..."
docker run -d --name "${CONTAINER_NAME}" \
    --cap-drop ALL \
    --cap-add SYS_NICE \
    --security-opt no-new-privileges:true \
    -e MYSQL_ROOT_PASSWORD="${ROOT_PASSWORD}" \
    -e MYSQL_DATABASE="${DATABASE}" \
    -e MYSQL_USER="${USER}" \
    -e MYSQL_PASSWORD="${USER_PASSWORD}" \
    -v "${VOLUME_NAME}:/var/lib/mysql" \
    -v "${TMPINIT}:/docker-entrypoint-initdb.d:ro" \
    "${IMAGE}"

echo "Waiting for Docker healthcheck to report healthy..."
for i in $(seq 1 60); do
    STATUS="$(docker inspect --format '{{.State.Health.Status}}' "${CONTAINER_NAME}" 2>/dev/null || echo "missing")"
    if [ "${STATUS}" = "healthy" ]; then
        echo "OK: Container status is healthy"
        break
    fi
    if [ "${STATUS}" = "missing" ] || [ "$(docker inspect --format '{{.State.Running}}' "${CONTAINER_NAME}" 2>/dev/null || echo false)" != "true" ]; then
        echo "ERROR: Container exited prematurely"
        docker logs "${CONTAINER_NAME}" || true
        exit 1
    fi
    sleep 2
    if [ "${i}" -eq 60 ]; then
        echo "ERROR: Container did not become healthy within 120s (status=${STATUS})"
        docker logs "${CONTAINER_NAME}" || true
        exit 1
    fi
done

echo "Verifying non-root execution (UID 999)..."
UID_ACTUAL="$(docker exec "${CONTAINER_NAME}" id -u)"
if [ "${UID_ACTUAL}" != "999" ]; then
    echo "ERROR: Container running as UID ${UID_ACTUAL}, expected 999 (mysql)"
    exit 1
fi
echo "OK: Running as UID ${UID_ACTUAL} (mysql)"

echo "Verifying MySQL 8.4 server version..."
VER_OUT="$(docker exec -e MYSQL_PWD="${ROOT_PASSWORD}" "${CONTAINER_NAME}" /usr/bin/mysql -uroot -Nse "SELECT VERSION();")"
echo "Reported version: ${VER_OUT}"
if [[ "${VER_OUT}" != 8.4.* ]]; then
    echo "ERROR: Expected MySQL 8.4.x, got ${VER_OUT}"
    exit 1
fi

echo "Verifying user connection, initdb.d script, and CRUD operations..."
docker exec -e MYSQL_PWD="${USER_PASSWORD}" "${CONTAINER_NAME}" \
    /usr/bin/mysql -u"${USER}" "${DATABASE}" -Nse "SELECT note FROM init_marker WHERE id=1;" | grep -qx "initialized"
echo "OK: User connection and /docker-entrypoint-initdb.d verified"

docker exec -e MYSQL_PWD="${ROOT_PASSWORD}" "${CONTAINER_NAME}" /usr/bin/mysql -uroot -e "
    CREATE DATABASE IF NOT EXISTS smoke_test;
    USE smoke_test;
    CREATE TABLE items (id INT PRIMARY KEY, val VARCHAR(64));
    INSERT INTO items VALUES (1, 'ok');
    SELECT val FROM items WHERE id=1;
" | grep -qx "ok"
echo "OK: Database and table CRUD verified"

echo "Verifying mysqldump..."
DUMP_OUT="$(docker exec -e MYSQL_PWD="${ROOT_PASSWORD}" "${CONTAINER_NAME}" /usr/bin/mysqldump -uroot --single-transaction smoke_test)"
printf '%s\n' "${DUMP_OUT}" | grep -q "CREATE TABLE"
echo "OK: mysqldump verified"

echo "Verifying datadir ownership..."
DATADIR_OWNER="$(docker exec "${CONTAINER_NAME}" stat -c '%U:%G' /var/lib/mysql)"
if [ "${DATADIR_OWNER}" != "mysql:mysql" ]; then
    echo "ERROR: Datadir ownership is ${DATADIR_OWNER}, expected mysql:mysql"
    exit 1
fi
echo "OK: Datadir ownership is ${DATADIR_OWNER}"

echo "Running negative healthcheck test..."
if docker exec "${CONTAINER_NAME}" healthcheck.sh --socket=/nonexistent/mysqld.sock >/dev/null 2>&1; then
    echo "ERROR: Healthcheck unexpectedly passed with nonexistent socket"
    exit 1
fi
echo "OK: Negative healthcheck failed as expected"

echo "=== All smoke tests passed for ${IMAGE} ==="
