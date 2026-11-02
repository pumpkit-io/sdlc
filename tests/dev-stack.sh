#!/usr/bin/env bash
# Runs skills/auto/dev-stack/scripts/dev-stack.template.sh (strategy A) against fake portless, docker, curl, node and npx.
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
esac
exit 0
EOF

# Containers, volumes and databases are files under $fake/docker.
cat > "$fake/bin/docker" <<EOF
#!/usr/bin/env bash
d="$fake/docker"
EOF
cat >> "$fake/bin/docker" <<'EOF'
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
# With $fake/steal-lock holding a pid, the fetch hands the fetch lock to that pid, as a takeover would.
cat > "$fake/bin/npx" <<EOF
#!/usr/bin/env bash
fake="$fake"
lock="$scratch/sdlc-emulate-fetch.lock"
EOF
cat >> "$fake/bin/npx" <<'EOF'
echo "npx $*" >> "$fake/events"
if [ -s "$fake/steal-lock" ]; then rm -rf "$lock"; ln -sn "$(cat "$fake/steal-lock")" "$lock"; rm -f "$fake/steal-lock"; fi
pkg=""
for a in "$@"; do case "$a" in -*) ;; *) pkg="$a"; break ;; esac; done
if [ ! -e "$fake/npx-cache/$pkg" ]; then
  echo "$pkg" >> "$fake/fetches"
  sleep 1
  mkdir -p "$fake/npx-cache" && touch "$fake/npx-cache/$pkg"
fi
EOF
printf '#!/usr/bin/env bash\necho "$*" >> "%s/node.log"\n' "$fake" > "$fake/bin/node"
chmod +x "$fake/bin/"* "$fake/portless-bin/"*

with_portless="$fake/portless-bin:$fake/bin:/usr/bin:/bin:/usr/sbin:/sbin"
without_portless="$fake/bin:/usr/bin:/bin:/usr/sbin:/sbin"
stack() { (cd "$wt" && PATH="$1" TMPDIR="$scratch" bash scripts/dev-stack "${@:2}" </dev/null); }
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
check "and no fetch lock was taken" "no" "$([ -e "$scratch/sdlc-emulate-fetch.lock" ] || [ -L "$scratch/sdlc-emulate-fetch.lock" ] && echo yes || echo no)"
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
check "and the fetch lock is released" "no" "$([ -e "$scratch/sdlc-emulate-fetch.lock" ] || [ -L "$scratch/sdlc-emulate-fetch.lock" ] && echo yes || echo no)"
stack "$with_portless" destroy >/dev/null 2>&1
wt="$emu/.claude/worktrees/signin"; stack "$with_portless" destroy >/dev/null 2>&1

echo "# a fetch lock left by a dead up"
lock="$scratch/sdlc-emulate-fetch.lock"
rm -rf "$fake/npx-cache" "$fake/fetches" "$lock"
true & dead=$!; wait "$dead"
ln -sn "$dead" "$lock"
wt="$emu/.claude/worktrees/signin"; stack "$with_portless" up >/dev/null 2>&1 & first=$!
wt="$emu/.claude/worktrees/billing"; stack "$with_portless" up >/dev/null 2>&1 & second=$!
start=$SECONDS
wait "$first"; code1=$?
wait "$second"; code2=$?
check "two ups waiting on it both succeed" "0 0" "$code1 $code2"
check "without waiting out the timeout" "yes" "$([ $((SECONDS - start)) -lt 30 ] && echo yes)"
check "and fetch the package once" "emulate@0.13.0" "$(cat "$fake/fetches" 2>/dev/null | tr '\n' ' ' | sed 's/ $//')"
check "and leave no lock behind" "" "$(ls -d "$lock"* 2>/dev/null)"
wt="$emu/.claude/worktrees/billing"; stack "$with_portless" destroy >/dev/null 2>&1
wt="$emu/.claude/worktrees/signin"; stack "$with_portless" destroy >/dev/null 2>&1

echo "# a fetch lock another up took over"
rm -rf "$fake/npx-cache" "$fake/fetches"
sleep 600 & other=$!
printf '%s\n' "$other" > "$fake/steal-lock"
stack "$with_portless" up >/dev/null 2>&1
check "release leaves the other up's lock" "$other" "$(readlink "$lock" 2>/dev/null)"
kill "$other"; wait "$other" 2>/dev/null
rm -f "$lock"
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

finish_tests
