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

# A worker with an outside effect points at an Emulator or is switched off here. TODO: list this app's switches.
safe_mode_env() {
  export MAIL_TRANSPORT="console"
}

# Emulators, as "<service> <path that answers 200>": "google /.well-known/openid-configuration", "stripe /v1/customers".
EMULATORS=()
EMULATE_VERSION="0.13.0"

# The variables the app reads each Emulator's URLs from, and an Emulator's webhook target and signing secret.
emulator_env() {
  # Assign before export: export would hide a failed emulator_url from set -e.
  # GOOGLE_ISSUER=$(emulator_url google); export GOOGLE_ISSUER
  # export STRIPE_WEBHOOK_URL="$DEV_URL/api/webhooks/stripe" STRIPE_WEBHOOK_SECRET="whsec_dev"
  :
}

# Every route change would otherwise rewrite /etc/hosts, which needs root.
export PORTLESS_SYNC_HOSTS=0

ROOT=$(git rev-parse --show-toplevel)
STATE_DIR="$ROOT/.sdlc/dev-stack"
cd "$ROOT"

note() { printf 'dev-stack: %s\n' "$*" >&2; }
die() { note "$*"; exit 1; }

has_portless() { command -v portless >/dev/null; }

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

# Without Portless, down and destroy still find their names: the Slug rule of the worktrees skill, applied to the branch.
local_host() {
  local branch slug=""
  if [ "$(git rev-parse --absolute-git-dir)" != "$(git rev-parse --path-format=absolute --git-common-dir)" ]; then
    branch=$(git branch --show-current)
    slug=$(printf '%s' "${branch##*/}" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9-]/-/g' -e 's/--*/-/g' -e 's/^-//' -e 's/-$//' | cut -c1-63)
    slug="${slug%-}."
  fi
  printf '%s%s.localhost\n' "$slug" "$PROJECT"
}

# The hostname comes from Portless, so the Slug matches the one portless run derives.
init_names() {
  local got=""
  if has_portless; then
    got=$(portless get "$PROJECT" </dev/null) || die "portless get $PROJECT failed"
    HOST=${got#*://}
    HOST=${HOST%%[:/]*}
  else
    HOST=$(local_host)
  fi
  ROUTE=${HOST%.localhost}
  if [ "$ROUTE" = "$PROJECT" ]; then
    SLUG=""
  else
    SLUG=${ROUTE%".$PROJECT"}
  fi
  # The Main checkout's names carry no slug, so no branch, not even one ending in main, can share them.
  if [ -n "$SLUG" ]; then
    COMPOSE_PROJECT="$PROJECT-$SLUG"
    DB_NAME=$(printf '%s_%s' "$PROJECT" "$SLUG" | tr -c 'a-z0-9_' '_' | cut -c1-63)
  else
    COMPOSE_PROJECT="$PROJECT"
    DB_NAME=$(printf '%s' "$PROJECT" | tr -c 'a-z0-9_' '_' | cut -c1-63)
  fi
  if [ -n "$got" ] && proxy_running; then
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

answers() {
  local args=()
  while IFS= read -r a; do args+=("$a"); done < <(curl_ca)
  curl -fsS -o /dev/null -m 5 ${args[@]+"${args[@]}"} "$1" 2>/dev/null
}

healthy() { answers "$DEV_URL$HEALTH_PATH"; }

emulator_url() { portless get "$1.emulate.$PROJECT" </dev/null || die "portless get $1.emulate.$PROJECT failed"; }

# A malformed entry would poll a broken URL until the timeout, so up refuses it first.
check_emulators() {
  local e
  for e in ${EMULATORS[@]+"${EMULATORS[@]}"}; do
    [[ "$e" =~ ^[a-z0-9-]+\ /[^\ ]*$ ]] || die "EMULATORS entry \"$e\" needs a service and a path that starts with /"
  done
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

a_started_at() { ps -o lstart= -p "$1" 2>/dev/null || true; }

# A pid file holds the pid and its start time, so a pid the system reused is never trusted or killed.
a_service_pid() {
  local f pid started
  f=$(a_pidfile "$1")
  [ -f "$f" ] || return 1
  pid=$(sed -n 1p "$f")
  started=$(sed -n 2p "$f")
  [ -n "$pid" ] && [ -n "$started" ] && [ "$(a_started_at "$pid")" = "$started" ] || return 1
  printf '%s\n' "$pid"
}

a_service_alive() { a_service_pid "$1" >/dev/null; }

a_emulators_alive() {
  local e
  for e in ${EMULATORS[@]+"${EMULATORS[@]}"}; do
    a_service_alive "emulate-${e%% *}" || return 1
  done
}

a_alive() { a_service_alive web && a_emulators_alive; }

a_start_service() {
  local svc=$1 name=$2 pid
  shift 2
  a_service_alive "$svc" && return 0
  nohup portless run --name "$name" "$@" >"$(a_logfile "$svc")" 2>&1 </dev/null &
  pid=$!
  printf '%s\n%s\n' "$pid" "$(a_started_at "$pid")" >"$(a_pidfile "$svc")"
}

# Starts the shared container, or creates it on first use.
a_pg_start() {
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
}

a_postgres() {
  a_pg_start
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

# Parallel first runs on a cold cache collide in npm's cache, so one fetch runs at a time per cache.
# The lock is a flock the kernel drops when its holder exits, so a dead up never leaves it held.
a_emulate_fetch() {
  local lock=${DEV_STACK_FETCH_LOCK:-} log="$STATE_DIR/emulate-fetch.log" cache code=0
  command -v perl >/dev/null || die "the Emulate fetch lock needs perl; install it and run up again"
  if [ -z "$lock" ]; then
    cache=$(npm config get cache 2>/dev/null </dev/null || true)
    lock="${cache:-$HOME/.npm}/_sdlc-emulate-fetch.lock"
  fi
  mkdir -p "$(dirname "$lock")" "$STATE_DIR"
  perl -MFcntl=:flock -e '
    open(my $f, ">>", shift) or exit 4;
    my $deadline = time + shift;
    until (flock($f, LOCK_EX | LOCK_NB)) { exit 3 if time >= $deadline; sleep 1 }
    exit(system(@ARGV) == 0 ? 0 : 1);
  ' "$lock" 600 npx --yes "emulate@$EMULATE_VERSION" --version </dev/null >"$log" 2>&1 || code=$?
  case "$code" in
    0) ;;
    3) die "another up has held $lock for 600s" ;;
    4) die "could not open $lock" ;;
    *) die "could not fetch emulate@$EMULATE_VERSION through npx; see $log" ;;
  esac
}

# For a config that leaves generated keys out, add --generated-secrets-file "$secrets"; emulate refuses an existing file, so up deletes it first.
a_start_emulator() {
  local svc=$1 secrets="$STATE_DIR/emulate-$1-secrets.json"
  a_service_alive "emulate-$svc" && return 0
  rm -f "$secrets"
  a_start_service "emulate-$svc" "$svc.emulate.$PROJECT" npx --yes "emulate@$EMULATE_VERSION" start --service "$svc"
}

a_wait_emulator() {
  local svc=$1 url deadline=$((SECONDS + HEALTH_TIMEOUT))
  url="$(emulator_url "$svc")$2"
  until answers "$url"; do
    a_service_alive "emulate-$svc" || die "the $svc Emulator exited before it answered; see: scripts/dev-stack logs emulate-$svc"
    [ "$SECONDS" -ge "$deadline" ] && die "no answer from $url after ${HEALTH_TIMEOUT}s; see: scripts/dev-stack logs emulate-$svc"
    sleep 1
  done
}

# Every Emulator starts, then each must answer, so an app that fetches OIDC discovery at boot finds it.
a_emulators_up() {
  local e
  [ "${#EMULATORS[@]}" -gt 0 ] || return 0
  emulator_env
  # A running stack skips the fetch, so it never waits behind another worktree's cold fetch.
  a_emulators_alive || a_emulate_fetch
  for e in "${EMULATORS[@]}"; do a_start_emulator "${e%% *}"; done
  for e in "${EMULATORS[@]}"; do a_wait_emulator "${e%% *}" "${e#* }"; done
}

a_up() {
  a_emulators_up
  a_postgres
  a_migrate >&2
  seed_once >&2
  # TODO: the app's dev server. Portless sets PORT and HOST, and passes --port to frameworks that ignore PORT.
  a_start_service web "$PROJECT" npm run dev
  # An extra service gets its own route: a_start_service api "api.$PROJECT" <command>,
  # and the web app reads its URL from: portless get "api.$PROJECT".
}

a_stop_service() {
  local svc=$1 pid i
  if pid=$(a_service_pid "$svc"); then
    kill "$pid" 2>/dev/null || true
    for i in $(seq 20); do
      a_service_alive "$svc" || break
      sleep 0.5
    done
    a_service_alive "$svc" && kill -9 "$pid" 2>/dev/null
  fi
  rm -f "$(a_pidfile "$svc")"
}

# Stopping portless run stops its server and removes its route.
a_down() {
  local f
  for f in "$STATE_DIR"/*.pid; do
    [ -f "$f" ] && a_stop_service "$(basename "$f" .pid)"
  done
  return 0
}

# The shared container stays up for the other worktrees; only this worktree's database goes.
# A stopped container still holds that database, so it is started to drop it before the seed marker goes.
a_destroy() {
  a_down
  if docker inspect "$A_PG_CONTAINER" >/dev/null 2>&1 || docker volume inspect "$A_PG_CONTAINER-data" >/dev/null 2>&1; then
    a_pg_start
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
    check_emulators
    has_portless || die "portless is not installed; run the Portless section of setup-sdlc"
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
