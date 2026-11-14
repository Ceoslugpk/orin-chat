# Syncing with upstream Chatwoot

Orin Chat started from a clean import of Chatwoot's MIT code without git
history, so that no commit in this repository contains Chatwoot's proprietary
`enterprise/` directory. Upstream changes are therefore brought in as filtered
patches, not merges.

The upstream commit the current code is based on is recorded in
[`.chatwoot-upstream`](../.chatwoot-upstream).

## Procedure

```bash
git remote add upstream https://github.com/chatwoot/chatwoot.git  # once
git fetch upstream

BASE=$(cat .chatwoot-upstream)
TARGET=$(git rev-parse upstream/develop)   # or a release tag, e.g. v4.20.0

git switch -c chore/upstream-sync-${TARGET:0:9}

# Apply everything except the proprietary edition.
git diff --binary "$BASE" "$TARGET" -- . ':(exclude)enterprise' ':(exclude)spec/enterprise' \
  | git apply --3way --index

echo "$TARGET" > .chatwoot-upstream
git add .chatwoot-upstream
```

Then:

1. Resolve conflicts. Prefer keeping Orin Chat's behaviour (no telemetry, no
   plan gating, branding) and re-applying the upstream intent around it.
2. Check that nothing new references `Enterprise::` or `enterprise/`, and that
   new calls to Chatwoot services (`ChatwootHub`, `chatwoot.com` URLs) are not
   introduced:
   ```bash
   git diff --cached | grep -nE 'Enterprise::|enterprise/|chatwoot\.com|ChatwootHub' || true
   ```
3. Run migrations and the test suite (`bin/toolbox bundle exec rspec`,
   `bin/toolbox pnpm test`).
4. Commit as `chore: sync with Chatwoot <short-sha or tag>` and open a PR.

## Rules

- Never copy files from upstream `enterprise/`, and never read them to
  implement an Orin Chat feature (see `AGENTS.md`, Licensing and Clean-Room
  Rules).
- Sync small and often: monthly, matching Chatwoot's release cadence.
