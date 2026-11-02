#!/usr/bin/env bash
# Runs skills/auto/dev-stack/scripts/dev-stack.template.sh (strategies A and B) against fake portless, docker, curl, node, npm and npx.
# Usage: tests/dev-stack.sh. Scratch repos go under $TMPDIR; no real container, proxy or route is touched.
set -u

template="$(cd "$(dirname "$0")/.." && pwd)/skills/auto/dev-stack/scripts/dev-stack.template.sh"
scratch="$(mktemp -d "${TMPDIR:-/tmp}/dev-stack-test.XXXXXX")"
. "$(dirname "$0")/lib.sh"
fake="$scratch/fake"
mkdir -p "$fake/bin" "$fake/portless-bin" "$fake/docker"
unrelated=""
cleanup() {
  [ -n "$unrelated" ] && { kill "$unrelated"; wait "$unrelated"; } 2>/dev/null
  pkill -f "$fake/portless-bin/portless run" 2>/dev/null
  rm -rf "$scratch"
}
trap cleanup EXIT

# Each portless run, Emulator poll and npx call appends a line to $fake/events.
cat > "$fake/portless-bin/portless" <<EOF
#!/usr/bin/env bash
events="$fake/events"
fake="$fake"
EOF
cat >> "$fake/portless-bin/portless" <<'EOF'
case "$1" in
  get)
    case "$2" in *.emulate.*) [ -e "$fake/portless-get-fails" ] && exit 1 ;; esac
    prefix=""
    if [ "$(git rev-parse --absolute-git-dir)" != "$(git rev-parse --path-format=absolute --git-common-dir)" ]; then
      b="$(git branch --show-current)"; prefix="${b##*/}."
    fi
    echo "http://$prefix$2.localhost:1355" ;;
  run) echo "run $3" >> "$events"; trap 'kill "$c" 2>/dev/null; exit 0' TERM; sleep 600 & c=$!; wait ;;
  alias)
    mkdir -p "$fake/aliases"
    if [ "$2" = --remove ]; then
      [ -e "$fake/aliases/$3" ] || exit 1
      rm "$fake/aliases/$3"; echo "unalias $3" >> "$events"
    else
      echo "$3" > "$fake/aliases/$2"; echo "alias $2" >> "$events"
    fi ;;
esac
exit 0
EOF

# Containers, volumes and databases are files under $fake/docker.
cat > "$fake/bin/docker" <<EOF
#!/usr/bin/env bash
d="$fake/docker"
EOF
cat >> "$fake/bin/docker" <<'EOF'
# docker compose -p <project> -f <file> <command>: a running service is a file b-<project>-<service>, each published port a file holding its host port.
if [ "$1" = compose ]; then
  p="$3"; shift 5
  case "$1" in
    up)
      svcs="${*:2}"; svcs="${svcs//-d/}"; svcs="${svcs//--build/}"; svcs="${svcs//--wait/}"; svcs=$(echo $svcs)
      echo "compose up $p${svcs:+ $svcs}" >> "$d/../events"
      echo "$EMULATE_SERVICES $EMULATE_BASE_URL ${GOOGLE_API_URL:-} ${STRIPE_API_URL:-} ${STRIPE_WEBHOOK_URL:-}" > "$d/env-$p"
      for s in ${svcs:-web emulate}; do
        [ "$s" = emulate ] && [ -e "$d/../emulate-dies" ] && continue
        touch "$d/b-$p-$s"
      done ;;
    port)
      f="$d/port-$p-$2-$3"
      if [ ! -e "$f" ]; then
        n=$(cat "$d/next-port" 2>/dev/null || echo 50000); echo $((n + 1)) > "$d/next-port"; echo "$n" > "$f"
      fi
      echo "127.0.0.1:$(cat "$f")" ;;
    ps) [ -e "$d/b-$p-${@: -1}" ] && echo "id-$p" ;;
    down) rm -f "$d/b-$p-"* "$d/port-$p-"* ;;
    exec) shift 3; node "$@" ;;
  esac
  exit 0
fi
case "$1" in
  inspect) [ -e "$d/c-${@: -1}" ] || exit 1; [ -e "$d/run-${@: -1}" ] && echo true || echo false ;;
  volume) [ -e "$d/v-${@: -1}" ] ;;
  run) name="$4"; [ -e "$d/c-$name" ] && exit 1; touch "$d/c-$name" "$d/v-$name-data" "$d/run-$name" ;;
  start) [ -e "$d/c-$2" ] && touch "$d/run-$2" ;;
  port) echo 127.0.0.1:55432 ;;
  exec)
    shift 2
    case "$1" in
      pg_isready) exit 0 ;;
      createdb) touch "$d/db-${@: -1}" ;;
      psql)
        q="${@: -1}"
        case "$q" in
          SELECT*) db="${q##*= \'}"; [ -e "$d/db-${db%\'}" ] && echo 1 ;;
          DROP*) db="${q#*EXISTS \"}"; rm -f "$d/db-${db%%\"*}" ;;
        esac ;;
    esac ;;
esac
EOF

# The proxy and every health check answer; each Emulator answers from its second poll on.
cat > "$fake/bin/curl" <<EOF
#!/usr/bin/env bash
fake="$fake"
EOF
cat >> "$fake/bin/curl" <<'EOF'
case " $* " in *" -w "*) printf 200; exit 0 ;; esac
url="${@: -1}"
case "$url" in
  *.emulate.*)
    host="${url#*://}"; host="${host%%/*}"
    if [ -e "$fake/answers-$host" ]; then rc=0; else touch "$fake/answers-$host"; rc=22; fi
    echo "ready ${url#*://} $rc" >> "$fake/events"
    exit "$rc" ;;
esac
exit 0
EOF
# The first call for a package fetches it into $fake/npx-cache, slowly enough for two cold runs to overlap.
cat > "$fake/bin/npx" <<EOF
#!/usr/bin/env bash
fake="$fake"
EOF
cat >> "$fake/bin/npx" <<'EOF'
echo "npx $*" >> "$fake/events"
[ -e "$fake/npx-fails" ] && { echo "npm error 404 emulate not found" >&2; exit 1; }
pkg=""
for a in "$@"; do case "$a" in -*) ;; *) pkg="$a"; break ;; esac; done
if [ ! -e "$fake/npx-cache/$pkg" ]; then
  echo "$pkg" >> "$fake/fetches"
  sleep 1
  mkdir -p "$fake/npx-cache" && touch "$fake/npx-cache/$pkg"
fi
EOF
printf '#!/usr/bin/env bash\necho "$*" >> "%s/node.log"\n' "$fake" > "$fake/bin/node"
printf '#!/usr/bin/env bash\n[ "$*" = "config get cache" ] && echo "%s/npm-cache"\n' "$fake" > "$fake/bin/npm"
chmod +x "$fake/bin/"* "$fake/portless-bin/"*

with_portless="$fake/portless-bin:$fake/bin:/usr/bin:/bin:/usr/sbin:/sbin"
without_portless="$fake/bin:/usr/bin:/bin:/usr/sbin:/sbin"
stack() { (cd "$wt" && PATH="$1" TMPDIR="$scratch/tmp" bash scripts/dev-stack "${@:2}" </dev/null); }
mkdir -p "$scratch/tmp"
lock="$fake/npm-cache/_sdlc-emulate-fetch.lock"
# Holds the fetch lock for $1 seconds in the background, as another up's fetch would.
hold_lock() {
  mkdir -p "$(dirname "$lock")"
  perl -MFcntl=:flock -e 'open(my $f, ">>", $ARGV[0]) or die; flock($f, LOCK_EX) or die; open(my $r, ">", "$ARGV[0].held"); close $r; sleep $ARGV[1]' "$lock" "$1" &
  holder=$!
  until [ -e "$lock.held" ]; do sleep 0.1; done
  rm -f "$lock.held"
}
events() { grep -E "^($1)" "$fake/events" 2>/dev/null | tr '\n' '|'; }
seeds() { grep -c seed.js "$fake/node.log" 2>/dev/null || echo 0; }

repo="$(new_repo app)"
mkdir -p "$repo/scripts"
cp "$template" "$repo/scripts/dev-stack"
printf '.sdlc/\n.claude/worktrees/\n' > "$repo/.gitignore"
git -C "$repo" add -A && git -C "$repo" commit -q -m contract
git -C "$repo" worktree add -q -b feat/login "$repo/.claude/worktrees/login"
wt="$repo/.claude/worktrees/login"

echo "# up"
check "prints the Dev URL" "http://login.myapp.localhost:1355" "$(stack "$with_portless" up 2>/dev/null | tail -n 1)"
check "creates this worktree's database" "yes" "$([ -e "$fake/docker/db-myapp_login" ] && echo yes)"
check "seeds once" "1" "$(seeds)"
check "status" "running" "$(stack "$with_portless" status 2>/dev/null)"
check "with no Emulators nothing runs through npx" "" "$(events npx)"
check "and the web route is the only one" "run myapp|" "$(events run)"
check "and the state is the web service's and the seed marker" "seeded web.log web.pid" "$(ls "$wt/.sdlc/dev-stack" | tr '\n' ' ' | sed 's/ $//')"

echo "# no Emulators on down and destroy"
check "the template ships an empty Emulator list" "1" "$(grep -c '^EMULATORS=()$' "$template")"
stack "$with_portless" down >/dev/null 2>&1
check "down leaves the seed marker and the log" "seeded web.log" "$(ls "$wt/.sdlc/dev-stack" | tr '\n' ' ' | sed 's/ $//')"
stack "$with_portless" destroy >/dev/null 2>&1
check "destroy leaves no state" "no" "$([ -e "$wt/.sdlc/dev-stack" ] && echo yes || echo no)"
check "and nothing ran through npx" "" "$(events npx)"
check "and no fetch lock was taken" "no" "$([ -e "$lock" ] && echo yes || echo no)"
stack "$with_portless" up >/dev/null 2>&1

echo "# main checkout names"
wt="$repo"
stack "$with_portless" up >/dev/null 2>&1
check "main checkout database has no slug" "yes" "$([ -e "$fake/docker/db-myapp" ] && echo yes)"
stack "$with_portless" destroy >/dev/null 2>&1
wt="$repo/.claude/worktrees/login"

echo "# reused pid"
stack "$with_portless" down >/dev/null 2>&1
sleep 600 & unrelated=$!
printf '%s\n' "$unrelated" > "$wt/.sdlc/dev-stack/web.pid"
stack "$with_portless" down >/dev/null 2>&1
check "down leaves an unrelated process alone" "alive" "$(kill -0 "$unrelated" 2>/dev/null && echo alive)"
printf '%s\n' "$unrelated" > "$wt/.sdlc/dev-stack/web.pid"
stack "$with_portless" up >/dev/null 2>&1
check "up starts the service instead of trusting the pid" "yes" "$([ "$(sed -n 1p "$wt/.sdlc/dev-stack/web.pid")" != "$unrelated" ] && echo yes)"
check "and the unrelated process lives" "alive" "$(kill -0 "$unrelated" 2>/dev/null && echo alive)"

echo "# destroy with the shared container stopped"
rm -f "$fake/docker/run-myapp-postgres"
stack "$with_portless" destroy >/dev/null 2>&1
check "drops the database" "no" "$([ -e "$fake/docker/db-myapp_login" ] && echo yes || echo no)"
before="$(seeds)"
stack "$with_portless" up >/dev/null 2>&1
check "the next up seeds the new database once" "$((before + 1))" "$(seeds)"

echo "# without portless"
out="$(stack "$without_portless" down 2>&1)"; code=$?
check "down works" "0" "$code"
check "and stops the service" "stopped" "$(stack "$with_portless" status 2>/dev/null)"
stack "$with_portless" up >/dev/null 2>&1
out="$(stack "$without_portless" destroy 2>&1)"; code=$?
check "destroy works" "0" "$code"
check "and drops this worktree's database" "no" "$([ -e "$fake/docker/db-myapp_login" ] && echo yes || echo no)"
check "up still needs portless" "1" "$(stack "$without_portless" up >/dev/null 2>&1; echo $?)"

echo "# Emulators"
emu="$(new_repo emu)"
mkdir -p "$emu/scripts"
sed 's|^EMULATORS=()$|EMULATORS=("google /.well-known/openid-configuration" "stripe /v1/customers")|' "$template" > "$emu/scripts/dev-stack"
check "the filled-in list names the Emulators" "1" "$(grep -c '^EMULATORS=("google' "$emu/scripts/dev-stack")"
printf '.sdlc/\n.claude/worktrees/\n' > "$emu/.gitignore"
git -C "$emu" add -A && git -C "$emu" commit -q -m contract
git -C "$emu" worktree add -q -b feat/signin "$emu/.claude/worktrees/signin"
git -C "$emu" worktree add -q -b feat/billing "$emu/.claude/worktrees/billing"

echo "# two cold ups at once"
wt="$emu/.claude/worktrees/signin"; stack "$with_portless" up >/dev/null 2>&1 & first=$!
wt="$emu/.claude/worktrees/billing"; stack "$with_portless" up >/dev/null 2>&1 & second=$!
wait "$first"; code1=$?
wait "$second"; code2=$?
check "the first up succeeds" "0" "$code1"
check "the second up succeeds" "0" "$code2"
check "the package is fetched once" "emulate@0.13.0" "$(cat "$fake/fetches" 2>/dev/null | tr '\n' ' ' | sed 's/ $//')"
check "the fetch lock sits in npm's cache" "yes" "$([ -e "$lock" ] && echo yes)"
check "and not in TMPDIR" "" "$(ls "$scratch/tmp")"
stack "$with_portless" destroy >/dev/null 2>&1
wt="$emu/.claude/worktrees/signin"; stack "$with_portless" destroy >/dev/null 2>&1

echo "# a fetch lock left by a dead up"
rm -rf "$fake/npx-cache" "$fake/fetches"
hold_lock 600
kill "$holder"; wait "$holder" 2>/dev/null
wt="$emu/.claude/worktrees/signin"; stack "$with_portless" up >/dev/null 2>&1 & first=$!
wt="$emu/.claude/worktrees/billing"; stack "$with_portless" up >/dev/null 2>&1 & second=$!
start=$SECONDS
wait "$first"; code1=$?
wait "$second"; code2=$?
check "two ups waiting on it both succeed" "0 0" "$code1 $code2"
check "without waiting out the timeout" "yes" "$([ $((SECONDS - start)) -lt 30 ] && echo yes)"
check "and fetch the package once" "emulate@0.13.0" "$(cat "$fake/fetches" 2>/dev/null | tr '\n' ' ' | sed 's/ $//')"
wt="$emu/.claude/worktrees/billing"; stack "$with_portless" destroy >/dev/null 2>&1
wt="$emu/.claude/worktrees/signin"; stack "$with_portless" destroy >/dev/null 2>&1

echo "# a fetch lock another up holds"
rm -rf "$fake/npx-cache" "$fake/fetches" "$fake/events"
hold_lock 3
start=$SECONDS
stack "$with_portless" up >/dev/null 2>&1; code=$?
check "up succeeds" "0" "$code"
check "after the holder lets go" "yes" "$([ $((SECONDS - start)) -ge 2 ] && echo yes)"
wait "$holder" 2>/dev/null
stack "$with_portless" destroy >/dev/null 2>&1

echo "# the fetch lock override"
rm -rf "$fake/npx-cache"
(cd "$wt" && PATH="$with_portless" DEV_STACK_FETCH_LOCK="$scratch/override.lock" bash scripts/dev-stack up </dev/null >/dev/null 2>&1)
check "up takes the lock at DEV_STACK_FETCH_LOCK" "yes" "$([ -e "$scratch/override.lock" ] && echo yes)"
stack "$with_portless" destroy >/dev/null 2>&1

echo "# a running stack"
wt="$emu/.claude/worktrees/signin"
stack "$with_portless" up >/dev/null 2>&1
rm -f "$fake/events"
hold_lock 600
start=$SECONDS
stack "$with_portless" up >/dev/null 2>&1; code=$?
kill "$holder"; wait "$holder" 2>/dev/null
check "up succeeds with the fetch lock held" "0" "$code"
check "without waiting for it" "yes" "$([ $((SECONDS - start)) -lt 5 ] && echo yes)"
check "and fetches nothing" "" "$(events npx)"
stack "$with_portless" destroy >/dev/null 2>&1

echo "# a failed fetch"
rm -rf "$fake/npx-cache"
touch "$fake/npx-fails"
err="$(stack "$with_portless" up 2>&1 >/dev/null)"; code=$?
rm -f "$fake/npx-fails"
check "up fails" "1" "$code"
contains "and names the fetch log" ".sdlc/dev-stack/emulate-fetch.log" "$err"
contains "which holds npx's output" "npm error 404 emulate not found" "$(cat "$wt/.sdlc/dev-stack/emulate-fetch.log" 2>/dev/null)"
stack "$with_portless" destroy >/dev/null 2>&1

echo "# no Perl"
mkdir -p "$fake/no-perl"
for d in /usr/bin /bin /usr/sbin /sbin; do
  for f in "$d"/*; do
    case "${f##*/}" in perl*) continue ;; esac
    [ -e "$fake/no-perl/${f##*/}" ] || ln -s "$f" "$fake/no-perl/${f##*/}"
  done
done
no_perl="$fake/portless-bin:$fake/bin:$fake/no-perl"
check "the PATH has no perl" "" "$(PATH="$no_perl" command -v perl)"
rm -f "$fake/events"
err="$(stack "$no_perl" up 2>&1 >/dev/null)"; code=$?
check "up fails" "1" "$code"
contains "with a one-line reason" "the Emulate fetch lock needs perl" "$err"
check "and runs nothing through npx" "" "$(events npx)"
stack "$with_portless" destroy >/dev/null 2>&1

echo "# a malformed Emulator entry"
bad="$(new_repo bad)"
mkdir -p "$bad/scripts"
for entry in '"google"' '"google well-known"'; do
  sed "s|^EMULATORS=()\$|EMULATORS=($entry)|" "$template" > "$bad/scripts/dev-stack"
  wt="$bad"
  err="$(stack "$with_portless" up 2>&1 >/dev/null)"; code=$?
  check "up refuses $entry" "1" "$code"
  contains "with a one-line reason" "needs a service and a path that starts with /" "$err"
done
check "before starting anything" "" "$(ls "$bad/.sdlc/dev-stack" 2>/dev/null | grep emulate)"

echo "# portless get fails for an Emulator"
wt="$emu/.claude/worktrees/signin"
touch "$fake/portless-get-fails"
err="$(stack "$with_portless" up 2>&1 >/dev/null)"; code=$?
rm -f "$fake/portless-get-fails"
check "up fails" "1" "$code"
contains "and says why" "portless get google.emulate.myapp failed" "$err"
stack "$with_portless" destroy >/dev/null 2>&1

echo "# a failed portless get in emulator_env"
filled="$(new_repo filled)"
mkdir -p "$filled/scripts"
sed -e 's|^EMULATORS=()$|EMULATORS=("google /.well-known/openid-configuration")|' -e 's|^  # GOOGLE_ISSUER=|  GOOGLE_ISSUER=|' "$template" > "$filled/scripts/dev-stack"
check "the example fills in" "1" "$(grep -c '^  GOOGLE_ISSUER=' "$filled/scripts/dev-stack")"
wt="$filled"
rm -f "$fake/events"
touch "$fake/portless-get-fails"
err="$(stack "$with_portless" up 2>&1 >/dev/null)"; code=$?
rm -f "$fake/portless-get-fails"
check "stops up" "1" "$code"
contains "and says why" "portless get google.emulate.myapp failed" "$err"
check "before fetching or starting an Emulator" "" "$(events 'npx|run')"
stack "$with_portless" destroy >/dev/null 2>&1

echo "# up in a linked worktree"
wt="$emu/.claude/worktrees/signin"
stack "$with_portless" destroy >/dev/null 2>&1
rm -f "$fake/events" "$fake"/answers-*
stack "$with_portless" up >/dev/null 2>&1
check "starts each Emulator, waits for each to answer, then starts the web service" \
  "run google.emulate.myapp|run stripe.emulate.myapp|ready signin.google.emulate.myapp.localhost:1355/.well-known/openid-configuration 22|ready signin.google.emulate.myapp.localhost:1355/.well-known/openid-configuration 0|ready signin.stripe.emulate.myapp.localhost:1355/v1/customers 22|ready signin.stripe.emulate.myapp.localhost:1355/v1/customers 0|run myapp|" \
  "$(events 'run|ready')"
contains "runs the pinned emulate for one service" "npx --yes emulate@0.13.0 start --service google" \
  "$(ps -o command= -p "$(sed -n 1p "$wt/.sdlc/dev-stack/emulate-google.pid")")"

echo "# a dead Emulator"
check "status with every process up" "running" "$(stack "$with_portless" status 2>/dev/null)"
google="$(sed -n 1p "$wt/.sdlc/dev-stack/emulate-google.pid")"
kill "$google"; while kill -0 "$google" 2>/dev/null; do sleep 0.1; done
check "status reports it" "stopped" "$(stack "$with_portless" status 2>/dev/null)"
stack "$with_portless" up >/dev/null 2>&1

echo "# Emulators on down and destroy"
google="$(sed -n 1p "$wt/.sdlc/dev-stack/emulate-google.pid")"
stack "$with_portless" down >/dev/null 2>&1
check "down stops the Emulator, which removes its route" "stopped" "$(kill -0 "$google" 2>/dev/null && echo alive || echo stopped)"
check "and keeps its log" "yes" "$([ -e "$wt/.sdlc/dev-stack/emulate-google.log" ] && echo yes)"
touch "$wt/.sdlc/dev-stack/emulate-google-secrets.json"
stack "$with_portless" destroy >/dev/null 2>&1
check "destroy deletes its log" "no" "$([ -e "$wt/.sdlc/dev-stack/emulate-google.log" ] && echo yes || echo no)"
check "and its generated-secrets file" "no" "$([ -e "$wt/.sdlc/dev-stack/emulate-google-secrets.json" ] && echo yes || echo no)"

echo "# Emulators in the main checkout"
wt="$emu"
rm -f "$fake/events"
stack "$with_portless" up >/dev/null 2>&1
contains "the route has no slug" "ready google.emulate.myapp.localhost:1355/.well-known/openid-configuration 0" "$(events ready)"
stack "$with_portless" destroy >/dev/null 2>&1

echo "# strategy B without Emulators"
b="$(new_repo b)"
mkdir -p "$b/scripts"
sed 's|^STRATEGY="a"$|STRATEGY="b"|' "$template" > "$b/scripts/dev-stack"
check "the copy runs strategy B" "1" "$(grep -c '^STRATEGY="b"$' "$b/scripts/dev-stack")"
printf '.sdlc/\n.claude/worktrees/\n' > "$b/.gitignore"
git -C "$b" add -A && git -C "$b" commit -q -m contract
git -C "$b" worktree add -q -b feat/login "$b/.claude/worktrees/login"
wt="$b/.claude/worktrees/login"
rm -f "$fake/events"
check "up prints the Dev URL" "http://login.myapp.localhost:1355" "$(stack "$with_portless" up 2>/dev/null | tail -n 1)"
check "starts the Compose project once and aliases only the web route" "compose up myapp-login|alias login.myapp|" "$(events 'compose|alias|unalias')"
check "status" "running" "$(stack "$with_portless" status 2>/dev/null)"
stack "$with_portless" down >/dev/null 2>&1
check "down removes only the web route" "compose up myapp-login|alias login.myapp|unalias login.myapp|" "$(events 'compose|alias|unalias')"
stack "$with_portless" destroy >/dev/null 2>&1

echo "# strategy B with Emulators"
be="$(new_repo be)"
mkdir -p "$be/scripts"
sed -e 's|^STRATEGY="a"$|STRATEGY="b"|' \
  -e 's|^EMULATORS=()$|EMULATORS=("google /.well-known/openid-configuration" "stripe /v1/customers")|' \
  -e 's|^  # GOOGLE_API_URL=|  GOOGLE_API_URL=|' -e 's|^  # STRIPE_API_URL=|  STRIPE_API_URL=|' \
  -e 's|^  # export STRIPE_WEBHOOK_URL="http|  export STRIPE_WEBHOOK_URL="http|' "$template" > "$be/scripts/dev-stack"
check "the strategy B examples fill in" "3" "$(grep -cE '^  (GOOGLE_API_URL|STRIPE_API_URL|export STRIPE_WEBHOOK_URL="http)' "$be/scripts/dev-stack")"
printf '.sdlc/\n.claude/worktrees/\n' > "$be/.gitignore"
git -C "$be" add -A && git -C "$be" commit -q -m contract
git -C "$be" worktree add -q -b feat/signin "$be/.claude/worktrees/signin"
git -C "$be" worktree add -q -b feat/billing "$be/.claude/worktrees/billing"
wt="$be/.claude/worktrees/signin"
rm -f "$fake/events" "$fake"/answers-*
check "up prints the Dev URL" "http://signin.myapp.localhost:1355" "$(stack "$with_portless" up 2>/dev/null | tail -n 1)"
check "starts the emulate service, aliases each Emulator, waits for each to answer, then starts the rest" \
  "compose up myapp-signin emulate|alias signin.google.emulate.myapp|alias signin.stripe.emulate.myapp|ready signin.google.emulate.myapp.localhost:1355/.well-known/openid-configuration 22|ready signin.google.emulate.myapp.localhost:1355/.well-known/openid-configuration 0|ready signin.stripe.emulate.myapp.localhost:1355/v1/customers 22|ready signin.stripe.emulate.myapp.localhost:1355/v1/customers 0|compose up myapp-signin|alias signin.myapp|" \
  "$(events 'compose|alias|ready')"
check "each alias points at its Emulator's published port" \
  "$(cat "$fake/docker/port-myapp-signin-emulate-4000") $(cat "$fake/docker/port-myapp-signin-emulate-4001")" \
  "$(cat "$fake/aliases/signin.google.emulate.myapp") $(cat "$fake/aliases/signin.stripe.emulate.myapp")"
check "Compose gets the services in list order, the advertised URL and the server-to-server URLs" \
  "google,stripe http://signin.{service}.emulate.myapp.localhost:1355 http://emulate:4000 http://emulate:4001 http://web:3000/api/webhooks/stripe" \
  "$(cat "$fake/docker/env-myapp-signin")"
check "status" "running" "$(stack "$with_portless" status 2>/dev/null)"

echo "# two strategy B worktrees side by side"
wt="$be/.claude/worktrees/billing"
stack "$with_portless" up >/dev/null 2>&1
check "the second worktree gets its own alias" "$(cat "$fake/docker/port-myapp-billing-emulate-4000")" "$(cat "$fake/aliases/billing.google.emulate.myapp" 2>/dev/null)"
check "and the first keeps its own" "$(cat "$fake/docker/port-myapp-signin-emulate-4000")" "$(cat "$fake/aliases/signin.google.emulate.myapp" 2>/dev/null)"
check "on another port" "yes" "$([ "$(cat "$fake/aliases/billing.google.emulate.myapp")" != "$(cat "$fake/aliases/signin.google.emulate.myapp")" ] && echo yes)"

echo "# strategy B Emulators on down and destroy"
wt="$be/.claude/worktrees/signin"
stack "$with_portless" down >/dev/null 2>&1
check "down removes this worktree's routes" "" "$(ls "$fake/aliases" | grep '^signin\.')"
check "and leaves the other worktree's" "billing.google.emulate.myapp billing.myapp billing.stripe.emulate.myapp" "$(ls "$fake/aliases" | grep '^billing\.' | tr '\n' ' ' | sed 's/ $//')"
wt="$be/.claude/worktrees/billing"
stack "$with_portless" destroy >/dev/null 2>&1
check "destroy removes its routes too" "" "$(ls "$fake/aliases")"

echo "# strategy B Emulators in the main checkout"
wt="$be"
stack "$with_portless" up >/dev/null 2>&1
check "the routes have no slug" "google.emulate.myapp myapp stripe.emulate.myapp" "$(ls "$fake/aliases" | tr '\n' ' ' | sed 's/ $//')"
stack "$with_portless" destroy >/dev/null 2>&1

echo "# a strategy B emulate service that exits"
wt="$be/.claude/worktrees/signin"
rm -f "$fake"/answers-*
touch "$fake/emulate-dies"
err="$(stack "$with_portless" up 2>&1 >/dev/null)"; code=$?
rm -f "$fake/emulate-dies"
check "up fails" "1" "$code"
contains "and says why" "the google Emulator exited before it answered" "$err"
stack "$with_portless" destroy >/dev/null 2>&1

echo "# a strategy B Emulator removed from EMULATORS between up and down"
wt="$be/.claude/worktrees/signin"
stack "$with_portless" up >/dev/null 2>&1
sed -i.bak 's|^EMULATORS=(.*)$|EMULATORS=("google /.well-known/openid-configuration")|' "$wt/scripts/dev-stack"
stack "$with_portless" down >/dev/null 2>&1
check "down removes every route up added" "" "$(ls "$fake/aliases" | grep '^signin\.')"
mv "$wt/scripts/dev-stack.bak" "$wt/scripts/dev-stack"
stack "$with_portless" destroy >/dev/null 2>&1

echo "# a strategy B emulator_env line for a service missing from EMULATORS"
sed -i.bak 's|^EMULATORS=(.*)$|EMULATORS=("google /.well-known/openid-configuration")|' "$wt/scripts/dev-stack"
rm -f "$fake/events"
err="$(stack "$with_portless" up 2>&1 >/dev/null)"; code=$?
mv "$wt/scripts/dev-stack.bak" "$wt/scripts/dev-stack"
check "up fails" "1" "$code"
contains "and says why" "stripe is not in EMULATORS" "$err"
check "before Compose starts" "" "$(events 'compose up')"
stack "$with_portless" destroy >/dev/null 2>&1

finish_tests
