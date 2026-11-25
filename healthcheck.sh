#!/usr/bin/env bash
# Healthcheck for dgcosenza/mysql container
# Verifies MySQL server socket/protocol responsiveness (and authenticated query
# when credentials are provided via env or *_FILE).
set -euo pipefail

SOCKET="/var/run/mysqld/mysqld.sock"

while [ "$#" -gt 0 ]; do
    case "$1" in
        --socket=*)
            SOCKET="${1#*=}"
            ;;
        --socket)
            shift
            SOCKET="${1:?missing value for --socket}"
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 2
            ;;
    esac
    shift
done

if [ ! -S "${SOCKET}" ]; then
    echo "MySQL socket not found: ${SOCKET}" >&2
    exit 1
fi

PASS=""
if [ -n "${MYSQL_ROOT_PASSWORD_FILE:-}" ] && [ -r "${MYSQL_ROOT_PASSWORD_FILE}" ]; then
    PASS="$(< "${MYSQL_ROOT_PASSWORD_FILE}")"
elif [ -n "${MYSQL_ROOT_PASSWORD:-}" ]; then
    PASS="${MYSQL_ROOT_PASSWORD}"
fi

if [ -n "${PASS}" ]; then
    CNF="$(mktemp)"
    trap 'rm -f "${CNF}"' EXIT
    chmod 600 "${CNF}"
    printf '[client]\nuser=root\npassword=%s\n' "${PASS}" > "${CNF}"
    mysql --defaults-extra-file="${CNF}" --protocol=socket --socket="${SOCKET}" \
        --batch --skip-column-names --execute="SELECT 1;" >/dev/null
elif [ -n "${MYSQL_ALLOW_EMPTY_PASSWORD:-}" ]; then
    mysql --protocol=socket --socket="${SOCKET}" -u root \
        --batch --skip-column-names --execute="SELECT 1;" >/dev/null
else
    # Without credentials in env (e.g. MYSQL_RANDOM_ROOT_PASSWORD), verify mysqld
    # accepts MySQL protocol handshakes on the Unix socket.
    OUT="$(mysqladmin --protocol=socket --socket="${SOCKET}" ping 2>&1 || true)"
    if printf '%s' "${OUT}" | grep -qiE 'mysqld is alive|Access denied'; then
        exit 0
    fi
    echo "MySQL healthcheck failed: ${OUT}" >&2
    exit 1
fi
