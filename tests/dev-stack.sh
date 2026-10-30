#!/usr/bin/env bash
# Runs skills/dev-stack/scripts/dev-stack.template.sh (strategy A) against fake portless, docker, curl and node.
# Usage: tests/dev-stack.sh. Scratch repos go under $TMPDIR; no real container, proxy or route is touched.
set -u

template="$(cd "$(dirname "$0")/.." && pwd)/skills/dev-stack/scripts/dev-stack.template.sh"
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

cat > "$fake/portless-bin/portless" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  get)
    prefix=""
    if [ "$(git rev-parse --absolute-git-dir)" != "$(git rev-parse --path-format=absolute --git-common-dir)" ]; then
      b="$(git branch --show-current)"; prefix="${b##*/}."
    fi
    echo "http://$prefix$2.localhost:1355" ;;
  run) trap 'kill "$c" 2>/dev/null; exit 0' TERM; sleep 600 & c=$!; wait ;;
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

# The proxy and every health check answer.
printf '#!/usr/bin/env bash\ncase " $* " in *" -w "*) printf 200 ;; esac\nexit 0\n' > "$fake/bin/curl"
printf '#!/usr/bin/env bash\necho "$*" >> "%s/node.log"\n' "$fake" > "$fake/bin/node"
chmod +x "$fake/bin/"* "$fake/portless-bin/"*

with_portless="$fake/portless-bin:$fake/bin:/usr/bin:/bin:/usr/sbin:/sbin"
without_portless="$fake/bin:/usr/bin:/bin:/usr/sbin:/sbin"
stack() { (cd "$wt" && PATH="$1" bash scripts/dev-stack "${@:2}" </dev/null); }
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

finish_tests
