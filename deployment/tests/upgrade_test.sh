#!/usr/bin/env bash
# Run only extracted upgrade functions with local stubs; never execute the installer.
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
installer=${1:-"$script_dir/../setup_20.04.sh"}
test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT

load_function() {
  local name=$1 line definition= collecting=false
  while IFS= read -r line; do
    if [[ "$line" == "function $name() {" ]]; then
      collecting=true
    fi
    if [[ "$collecting" == true ]]; then
      definition+="$line"$'\n'
      if [[ "$line" == '}' ]]; then
        eval "$definition"
        return
      fi
    fi
  done < "$installer"
  printf 'Missing installer function: %s\n' "$name" >&2
  exit 1
}

load_function upgrade_prereq
load_function upgrade

# The child shells used by the sudo stub inherit only these command stubs.
git() {
  printf 'git %s\n' "$*" >> "$TRACE"
  if [[ "$1" == "$FAIL_STEP" ]]; then
    return 1
  fi
  case "$1" in
    remote)
      [[ "$2 $3" == 'get-url origin' ]] || return 99
      printf '%s\n' "$TEST_ORIGIN"
      ;;
    update-index|diff-index|fetch|checkout|pull) ;;
    *) return 99 ;;
  esac
}

rvm() {
  printf 'dependency rvm %s\n' "$*" >> "$TRACE"
  [[ "$FAIL_STEP" != rvm ]]
}
pnpm() {
  printf 'dependency pnpm %s\n' "$*" >> "$TRACE"
  [[ "$FAIL_STEP" != pnpm ]]
}
rake() {
  printf 'assets %s\n' "$*" >> "$TRACE"
  [[ "$FAIL_STEP" != assets ]]
}
bundle() {
  if [[ "${1:-}" == exec ]]; then
    printf 'migration %s\n' "$*" >> "$TRACE"
    [[ "$FAIL_STEP" != migration ]]
  else
    printf 'dependency bundle\n' >> "$TRACE"
    [[ "$FAIL_STEP" != bundle ]]
  fi
}
export -f git rvm pnpm rake bundle

sudo() (
  [[ "$1 $2 $3" == '-i -u chatwoot' ]] || exit 99
  shift 3
  cd -- "$TEST_HOME"
  if [[ "$#" -gt 0 ]]; then
    [[ "$1" == bash ]] || exit 99
    shift
  fi
  command bash --noprofile --norc "$@"
)

cwctl_upgrade_check() { printf 'dependency cwctl-check\n' >> "$TRACE"; }
get_cw_version() { CW_VERSION=4.19.1; }
install_libvips() { printf 'dependency libvips\n' >> "$TRACE"; }
upgrade_redis() { printf 'dependency redis\n' >> "$TRACE"; }
upgrade_node() { printf 'dependency node\n' >> "$TRACE"; }
get_pnpm() { printf 'dependency pnpm-setup\n' >> "$TRACE"; }
cp() { printf 'service-copy %s\n' "$*" >> "$TRACE"; }
systemctl() { printf 'service %s\n' "$*" >> "$TRACE"; }
sleep() { :; }

run_upgrade() {
  local name=$1
  export TEST_ORIGIN=$2 FAIL_STEP=$3
  BRANCH=${4:-main}
  export TRACE="$test_dir/$name.trace" TEST_HOME="$test_dir/$name"
  mkdir -p -- "$TEST_HOME/chatwoot"
  printf '3.4.4\n' > "$TEST_HOME/chatwoot/.ruby-version"
  : > "$TRACE"
  set +e
  (
    set -e
    upgrade <<< $'yes\nyes'
  ) > "$test_dir/$name.output" 2>&1
  result=$?
  set -e
}

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_stopped() {
  local name=$1
  [[ "$result" -ne 0 ]] || fail "$name returned success"
  if grep -Eq '^(dependency|assets|migration|service-copy|service) ' "$TRACE"; then
    fail "$name reached dependency, migration, or service changes"
  fi
  printf 'PASS: %s stops before changes\n' "$name"
}

# These must fail even when later git commands would succeed.
for step in fetch checkout pull remote update-index diff-index; do
  run_upgrade "$step-failure" 'https://github.com/Ceoslugpk/orin-chat.git' "$step"
  assert_stopped "$step-failure"
done

for origin in \
  'https://github.com/chatwoot/chatwoot.git' \
  'git@github.com:chatwoot/chatwoot.git' \
  'ssh://git@github.com/chatwoot/chatwoot.git' \
  'https://github.com/Chatwoot/Chatwoot.git/'; do
  run_upgrade legacy-upstream "$origin" none
  assert_stopped "legacy upstream ($origin)"
  grep -q 'migration.*not supported' "$test_dir/legacy-upstream.output" || fail 'missing migration warning'
  grep -qi 'back up' "$test_dir/legacy-upstream.output" || fail 'missing backup guidance'
  if grep -Eq '^git (fetch|checkout|pull)' "$TRACE"; then
    fail 'legacy upstream checkout was changed'
  fi
done

for step in rvm bundle pnpm assets migration; do
  run_upgrade "$step-failure" 'https://github.com/Ceoslugpk/orin-chat.git' "$step"
  [[ "$result" -ne 0 ]] || fail "$step failure returned success"
  if grep -Eq '^(service-copy|service) ' "$TRACE"; then
    fail "$step failure reached service changes"
  fi
  if [[ "$step" != migration ]] && grep -q '^migration ' "$TRACE"; then
    fail "$step failure reached database migrations"
  fi
  printf 'PASS: %s failure prevents later upgrade steps\n' "$step"
done

run_upgrade orin-success 'https://github.com/Ceoslugpk/orin-chat.git' none
[[ "$result" -eq 0 ]] || fail 'Orin upgrade failed'
grep -q '^git checkout main$' "$TRACE" || fail 'Orin branch was not selected'
grep -q '^migration ' "$TRACE" || fail 'Orin upgrade did not migrate'
grep -q '^service restart ' "$TRACE" || fail 'Orin upgrade did not restart'
printf 'PASS: Orin checkout upgrades normally\n'

run_upgrade custom-success 'git@code.example:operations/support-fork.git' none custom-release
[[ "$result" -eq 0 ]] || fail 'custom fork upgrade failed'
grep -q '^git checkout custom-release$' "$TRACE" || fail 'custom branch was not preserved'
grep -q '^migration ' "$TRACE" || fail 'custom fork did not migrate'
grep -q '^service restart ' "$TRACE" || fail 'custom fork did not restart'
printf 'PASS: custom fork and branch upgrade normally\n'

printf 'All upgrade regression tests passed.\n'
