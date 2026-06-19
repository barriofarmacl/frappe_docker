#!/usr/bin/env bash

set -euo pipefail

cd /home/frappe/frappe-bench

SITE_NAME="${SITE_NAME:-frontend}"
SITE_HOSTNAME="${SITE_HOSTNAME:?SITE_HOSTNAME is required}"
SITE_PROTOCOL="${SITE_PROTOCOL:-https}"
SITE_USE_SSL="${SITE_USE_SSL:-1}"
SITE_SOCKETIO_PORT="${SITE_SOCKETIO_PORT:-443}"
SITE_ADMIN_PASSWORD="${SITE_ADMIN_PASSWORD:?SITE_ADMIN_PASSWORD is required}"
DB_ROOT_USERNAME="${DB_ROOT_USERNAME:-root}"
DB_ROOT_PASSWORD="${DB_ROOT_PASSWORD:?DB_ROOT_PASSWORD is required}"
INSTALL_APPS="${INSTALL_APPS:-erpnext barriofarma_app}"

wait-for-it -t 120 db:3306
wait-for-it -t 120 redis-cache:6379
wait-for-it -t 120 redis-queue:6379

export start="$(date +%s)"
until [[ -n "$(jq -r '.db_host // empty' sites/common_site_config.json 2>/dev/null)" ]] && \
      [[ -n "$(jq -r '.redis_cache // empty' sites/common_site_config.json 2>/dev/null)" ]] && \
      [[ -n "$(jq -r '.redis_queue // empty' sites/common_site_config.json 2>/dev/null)" ]]; do
  echo "Waiting for sites/common_site_config.json to be created"
  sleep 5
  if (( "$(date +%s)" - start > 120 )); then
    echo "could not find sites/common_site_config.json with required keys"
    exit 1
  fi
done

SITE_PATH="sites/${SITE_NAME}/site_config.json"
SITE_DB_PASSWORD="${SITE_DB_PASSWORD:-$(openssl rand -base64 24 | tr -d '\n')}"

if [[ -f "${SITE_PATH}" ]]; then
  echo "Site ${SITE_NAME} already exists - skipping bench new-site"
else
  echo "Creating site ${SITE_NAME}"
  install_args=()
  for app in ${INSTALL_APPS}; do
    install_args+=(--install-app "${app}")
  done

  bench new-site \
    --db-type mariadb \
    --mariadb-user-host-login-scope='%' \
    --admin-password="${SITE_ADMIN_PASSWORD}" \
    --db-root-username="${DB_ROOT_USERNAME}" \
    --db-root-password="${DB_ROOT_PASSWORD}" \
    --db-password "${SITE_DB_PASSWORD}" \
    "${install_args[@]}" \
    --set-default "${SITE_NAME}"
fi

bench --site "${SITE_NAME}" set-config host_name "${SITE_PROTOCOL}://${SITE_HOSTNAME}"
bench --site "${SITE_NAME}" set-config nginx_port 8080
bench --site "${SITE_NAME}" set-config socketio_port "${SITE_SOCKETIO_PORT}"
bench --site "${SITE_NAME}" set-config socketio_host "${SITE_HOSTNAME}"
bench --site "${SITE_NAME}" set-config use_ssl "${SITE_USE_SSL}"
bench --site "${SITE_NAME}" clear-cache

echo "Site ${SITE_NAME} configured successfully"
