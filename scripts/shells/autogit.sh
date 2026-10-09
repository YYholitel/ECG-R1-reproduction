#!/usr/bin/env bash
# Periodic snapshot of the reproduction repo: commit and push whatever changed.
#
#   Installed as a cron job (see install_autogit_cron.sh), so the remote copy of
#   this repository keeps pace without anyone remembering to push.
#
# Guard rails:
#   * never stages anything above MAX_MB (default 3000 MB, the agreed ceiling)
#   * never stages anything above GitHub's hard 100 MB per-file limit
#   * if an oversized file is already tracked/ignored incorrectly, the commit is
#     aborted and the index is reset rather than pushing something broken
set -uo pipefail
PROJ=${PROJ:-/data/lihy/ECG-R1_repoduction}
MAX_MB=${MAX_MB:-3000}
GITHUB_LIMIT_MB=${GITHUB_LIMIT_MB:-100}
BRANCH=${BRANCH:-main}
LOG=${LOG:-/data/lihy/autogit.log}

exec >>"$LOG" 2>&1
echo "----- $(date '+%F %T') -----"
cd "$PROJ" || { echo "FATAL: cannot cd $PROJ"; exit 1; }

if command -v flock >/dev/null 2>&1; then
  exec 9>/tmp/.ecg_autogit.lock
  flock -n 9 || { echo "another run holds the lock; skipping"; exit 0; }
fi

if [ -z "$(git status --porcelain)" ]; then
  echo "no changes"
  exit 0
fi

git add -A

blocked=""
while IFS= read -r f; do
  [ -f "$f" ] || continue
  sz=$(stat -c %s "$f" 2>/dev/null || echo 0)
  mb=$(( sz / 1024 / 1024 ))
  [ "$mb" -gt "$MAX_MB" ] && blocked="${blocked}"$'\n'"  over ${MAX_MB}MB : ${mb}MB  $f"
  [ "$mb" -gt "$GITHUB_LIMIT_MB" ] && blocked="${blocked}"$'\n'"  over GitHub ${GITHUB_LIMIT_MB}MB : ${mb}MB  $f"
done < <(git diff --cached --name-only --diff-filter=ACM)

if [ -n "$blocked" ]; then
  echo "ABORT: oversized file(s) staged:$blocked"
  git reset -q
  exit 1
fi

staged=$(git diff --cached --name-only | wc -l)
git -c i18n.commitEncoding=UTF-8 commit -q -m "自动快照 $(date '+%F %T')（${staged} 个文件）" \
  && echo "committed $(git rev-parse --short HEAD) ($staged files)"
if git push -q origin "$BRANCH"; then
  echo "pushed -> origin/$BRANCH"
else
  echo "PUSH FAILED"
  exit 1
fi
