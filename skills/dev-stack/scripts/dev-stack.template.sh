#!/usr/bin/env bash
# Dev stack contract for this repo: up | down | destroy | url | status | logs [service].
# Drafted from the sdlc dev-stack template; the rules are in that skill's CONTRACT.md.
# Keep the strategy block that fits this repo, delete the other, and fill each marked placeholder.
set -euo pipefail

# Recorded in docs/agents/dev-stack.md; keep the two in step.
PROJECT="myapp"
STRATEGY="a"
PROXY_PORT=1355
PROXY_TLS=0
HEALTH_PATH="/health"
HEALTH_TIMEOUT=120
# The variable the app reads its own public URL from.
APP_URL_VAR="APP_URL"

# Workers that act on the outside world stay off or point at fakes. TODO: list this app's switches.
safe_mode_env() {
  export MAIL_TRANSPORT="console"
}

# Every route change would otherwise rewrite /etc/hosts, which needs root.
export PORTLESS_SYNC_HOSTS=0

ROOT=$(git rev-parse --show-toplevel)
STATE_DIR="$ROOT/.sdlc/dev-stack"
cd "$ROOT"

note() { printf 'dev-stack: %s\n' "$*" >&2; }
die() { note "$*"; exit 1; }

command -v portless >/dev/null || die "portless is not installed; run the Portless section of setup-sdlc"

# Any HTTP answer counts, so a proxy in either mode is found on its port.
proxy_running() {
  local code
  code=$(curl -s -o /dev/null -m 2 -w '%{http_code}' "http://127.0.0.1:$PROXY_PORT/" || true)
  [ "${code:-000}" != "000" ]
}

ensure_proxy() {
  proxy_running && return 0
  if [ "$PROXY_PORT" -lt 1024 ]; then
    die "no Portless proxy on port $PROXY_PORT, and starting one there needs sudo; rerun the HTTPS upgrade command in docs/agents/dev-stack.md"
  fi
  local tls_flag=--no-tls
  [ "$PROXY_TLS" = 1 ] && tls_flag=--https
  portless proxy start -p "$PROXY_PORT" "$tls_flag" </dev/null >&2 || die "could not start the Portless proxy"
}

# The hostname comes from Portless, so the Slug matches the one portless run derives.
init_names() {
  local got
  got=$(portless get "$PROJECT" </dev/null) || die "portless get $PROJECT failed"
  HOST=${got#*://}
  HOST=${HOST%%[:/]*}
  ROUTE=${HOST%.localhost}
  if [ "$ROUTE" = "$PROJECT" ]; then
    SLUG=""
  else
    SLUG=${ROUTE%".$PROJECT"}
  fi
  # The Main checkout has no prefix in its route; its other names use "main".
  NAME_SLUG=${SLUG:-main}
  COMPOSE_PROJECT="$PROJECT-$NAME_SLUG"
  DB_NAME=$(printf '%s_%s' "$PROJECT" "$NAME_SLUG" | tr -c 'a-z0-9_' '_' | cut -c1-63)
  if proxy_running; then
    DEV_URL=$got
  else
    local scheme=http port_part=":$PROXY_PORT"
    [ "$PROXY_TLS" = 1 ] && scheme=https
    if { [ "$PROXY_TLS" = 1 ] && [ "$PROXY_PORT" = 443 ]; } || { [ "$PROXY_TLS" = 0 ] && [ "$PROXY_PORT" = 80 ]; }; then
      port_part=""
    fi
    DEV_URL="$scheme://$HOST$port_part"
  fi
  # Compose files interpolate it on every command, not only on up.
  export "$APP_URL_VAR=$DEV_URL"
}

# In HTTPS mode, trust the Portless CA for this request only.
curl_ca() {
  local ca="${PORTLESS_STATE_DIR:-$HOME/.portless}/ca.pem"
  case "$DEV_URL" in
    https://*) [ -f "$ca" ] && printf -- '--cacert\n%s\n' "$ca" ;;
  esac
  return 0
}

healthy() {
  local args=()
  while IFS= read -r a; do args+=("$a"); done < <(curl_ca)
  curl -fsS -o /dev/null -m 5 ${args[@]+"${args[@]}"} "$DEV_URL$HEALTH_PATH" 2>/dev/null
}

wait_healthy() {
  local deadline=$((SECONDS + HEALTH_TIMEOUT))
  until healthy; do
    "${STRATEGY}_alive" || die "the stack exited before it was healthy; see: scripts/dev-stack logs"
    [ "$SECONDS" -ge "$deadline" ] && die "no healthy answer from $DEV_URL$HEALTH_PATH after ${HEALTH_TIMEOUT}s; see: scripts/dev-stack logs"
    sleep 1
  done
}

# Seed once per data set; destroy removes the marker with the data.
seed_once() {
  [ -f "$STATE_DIR/seeded" ] && return 0
  "${STRATEGY}_seed"
  touch "$STATE_DIR/seeded"
}

# Strategy A: native processes behind portless run, one shared Postgres container.

A_PG_CONTAINER="$PROJECT-postgres"
A_PG_IMAGE="postgres:16-alpine"

a_pidfile() { printf '%s/%s.pid' "$STATE_DIR" "$1"; }
a_logfile() { printf '%s/%s.log' "$STATE_DIR" "$1"; }

a_service_alive() {
  local f
  f=$(a_pidfile "$1")
  [ -f "$f" ] && kill -0 "$(cat "$f")" 2>/dev/null
}

a_alive() { a_service_alive web; }

# Usage: a_start_service <service> <portless name> <command...>
a_start_service() {
  local svc=$1 name=$2
  shift 2
  a_service_alive "$svc" && return 0
  nohup portless run --name "$name" "$@" >"$(a_logfile "$svc")" 2>&1 </dev/null &
  echo $! >"$(a_pidfile "$svc")"
}

a_postgres() {
  local i
  # A parallel up may be creating the container; keep starting it until one attempt wins.
  for i in $(seq 30); do
    [ "$(docker inspect -f '{{.State.Running}}' "$A_PG_CONTAINER" 2>/dev/null)" = "true" ] && break
    docker run -d --name "$A_PG_CONTAINER" -e POSTGRES_PASSWORD=dev -p 127.0.0.1::5432 \
      -v "$A_PG_CONTAINER-data:/var/lib/postgresql/data" "$A_PG_IMAGE" >/dev/null 2>&1 ||
      docker start "$A_PG_CONTAINER" >/dev/null 2>&1 || true
    [ "$i" = 30 ] && die "could not start $A_PG_CONTAINER"
    sleep 1
  done
  for i in $(seq 60); do
    docker exec "$A_PG_CONTAINER" pg_isready -U postgres -q 2>/dev/null && break
    [ "$i" = 60 ] && die "$A_PG_CONTAINER did not accept connections"
    sleep 1
  done
  if [ "$(docker exec "$A_PG_CONTAINER" psql -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'")" != "1" ]; then
    docker exec "$A_PG_CONTAINER" createdb -U postgres "$DB_NAME"
  fi
  local hostport
  hostport=$(docker port "$A_PG_CONTAINER" 5432/tcp | head -n 1)
  export DATABASE_URL="postgres://postgres:dev@127.0.0.1:${hostport##*:}/$DB_NAME"
}

# TODO: the app's migration and seed commands. Migrations run on every up and must be idempotent.
a_migrate() { node scripts/migrate.js; }
a_seed() { node scripts/seed.js; }

a_up() {
  a_postgres
  a_migrate >&2
  seed_once >&2
  # TODO: the app's dev server. Portless sets PORT and HOST, and passes --port to frameworks that ignore PORT.
  a_start_service web "$PROJECT" npm run dev
  # An extra service gets its own route: a_start_service api "api.$PROJECT" <command>,
  # and the web app reads its URL from: portless get "api.$PROJECT".
}

a_stop_pid() {
  local f pid i
  f=$1
  pid=$(cat "$f")
  kill "$pid" 2>/dev/null || true
  for i in $(seq 20); do
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.5
  done
  kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null
  rm -f "$f"
}

# Stopping portless run stops its server and removes its route.
a_down() {
  local f
  for f in "$STATE_DIR"/*.pid; do
    [ -f "$f" ] && a_stop_pid "$f"
  done
  return 0
}

# The shared container stays up for the other worktrees; only this worktree's database goes.
a_destroy() {
  a_down
  if [ "$(docker inspect -f '{{.State.Running}}' "$A_PG_CONTAINER" 2>/dev/null)" = "true" ]; then
    docker exec "$A_PG_CONTAINER" psql -U postgres -qc "DROP DATABASE IF EXISTS \"$DB_NAME\" WITH (FORCE)" >&2
  fi
}

a_logs() {
  local f
  if [ -n "${1:-}" ]; then
    f=$(a_logfile "$1")
    [ -f "$f" ] || die "no log for service $1"
    tail -n 200 "$f"
    return
  fi
  for f in "$STATE_DIR"/*.log; do
    [ -f "$f" ] && printf '%s: %s\n' "$(basename "$f" .log)" "$f"
  done
  return 0
}

# Strategy B: Docker Compose behind portless alias, one Compose project per Slug.

# TODO: the dev Compose file, the web service and the port it listens on inside the container.
# The file publishes that port as "127.0.0.1::3000" and reads APP_URL from the environment.
B_COMPOSE_FILE="compose.dev.yml"
B_WEB_SERVICE="web"
B_WEB_PORT=3000

b_compose() { docker compose -p "$COMPOSE_PROJECT" -f "$ROOT/$B_COMPOSE_FILE" "$@"; }

b_alive() { [ -n "$(b_compose ps -q --status running "$B_WEB_SERVICE" 2>/dev/null)" ]; }

# TODO: the app's migration and seed commands, run inside the web container.
b_migrate() { b_compose exec -T "$B_WEB_SERVICE" node scripts/migrate.js; }
b_seed() { b_compose exec -T "$B_WEB_SERVICE" node scripts/seed.js; }

b_up() {
  b_compose up -d --build --wait >&2 || die "docker compose up failed; see: scripts/dev-stack logs"
  b_migrate >&2
  seed_once >&2
  local hostport
  hostport=$(b_compose port "$B_WEB_SERVICE" "$B_WEB_PORT") || die "$B_WEB_SERVICE does not publish port $B_WEB_PORT"
  # --force only ever re-points this worktree's own route at its new port.
  portless alias "$ROUTE" "${hostport##*:}" --force </dev/null >&2
}

b_down() {
  b_compose down >&2
  portless alias --remove "$ROUTE" </dev/null >/dev/null 2>&1 || true
}

b_destroy() {
  b_compose down -v --remove-orphans >&2
  portless alias --remove "$ROUTE" </dev/null >/dev/null 2>&1 || true
}

b_logs() { b_compose logs --no-color --tail 200 ${1+"$1"}; }

usage() { printf 'usage: scripts/dev-stack up|down|destroy|url|status|logs [service]\n' >&2; }

case "${1:-}" in
  up)
    ensure_proxy
    init_names
    mkdir -p "$STATE_DIR"
    safe_mode_env
    "${STRATEGY}_up"
    wait_healthy
    printf '%s\n' "$DEV_URL"
    ;;
  down)
    init_names
    "${STRATEGY}_down"
    ;;
  destroy)
    init_names
    "${STRATEGY}_destroy"
    rm -rf "$STATE_DIR"
    ;;
  url)
    init_names
    printf '%s\n' "$DEV_URL"
    ;;
  status)
    init_names
    if "${STRATEGY}_alive" && healthy; then
      echo running
    else
      echo stopped
      exit 3
    fi
    ;;
  logs)
    init_names
    "${STRATEGY}_logs" ${2+"$2"}
    ;;
  *)
    usage
    exit 2
    ;;
esac
