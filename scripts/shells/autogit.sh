#!/usr/bin/env bash
# Periodic snapshot of the reproduction repo: commit and push whatever changed.
# Installed as a cron job, so the remote copy keeps pace without anyone
# remembering to push.
#
# Guard rails, in order - each one exists because it has already been needed:
#   1. refuse to run at all if any git-lfs object is tracked (this repo must stay
#      LFS-free; a stray 17.75 GB model copy once got staged here)
#   2. stage with explicit pathspec exclusions for datasets and weights, so a
#      download landing inside the checkout can never be picked up
#   3. after staging, abort if any staged file exceeds MAX_MB (3000, the agreed
#      ceiling) or GitHub's hard 100 MB per-file limit, and reset the index
set -uo pipefail
PROJ=${PROJ:-/data/lihy/ECG-R1_repoduction}
MAX_MB=${MAX_MB:-3000}
GITHUB_LIMIT_MB=${GITHUB_LIMIT_MB:-100}
BRANCH=${BRANCH:-main}
LOG=${LOG:-/data/lihy/autogit.log}

# Paths that must never be staged even if .gitignore is ever weakened.
EXCLUDES=(
  ':(exclude)ECG-R1-8B-RL'
  ':(exclude)ECG-Protocol-Guided-Grounding-CoT'
  ':(exclude)stray_from_repo'
  ':(exclude)**/*.safetensors'
  ':(exclude)**/*.pt'
  ':(exclude)**/*.bin'
  ':(exclude)**/checkpoint/**'
)

exec >>"$LOG" 2>&1
echo "----- $(date '+%F %T') -----"
cd "$PROJ" || { echo "FATAL: cannot cd $PROJ"; exit 1; }

if command -v flock >/dev/null 2>&1; then
  exec 9>/tmp/.ecg_autogit.lock
  flock -n 9 || { echo "another run holds the lock; skipping"; exit 0; }
fi

lfs=$(git lfs ls-files 2>/dev/null | wc -l)
if [ "${lfs:-0}" -gt 0 ]; then
  echo "ABORT: ${lfs} git-lfs tracked file(s) present; this repo must stay LFS-free"
  git lfs ls-files | sed 's/^/  /'
  exit 1
fi

# Fail closed on any large untracked directory. Download tools keep dropping
# dataset checkouts into the repository; a single `git add` would sweep them in,
# and gitignore only protects the names we already know about.
BIG_DIR_MB=${BIG_DIR_MB:-50}
big_dirs=$(git status --porcelain --untracked-files=normal 2>/dev/null \
  | awk '$1=="??"{ $1=""; sub(/^ /,""); print }' \
  | while IFS= read -r d; do
      [ -d "$d" ] || continue
      mb=$(du -sm "$d" 2>/dev/null | cut -f1)
      [ "${mb:-0}" -gt "$BIG_DIR_MB" ] && printf '  %sMB  %s\n' "$mb" "$d"
    done)
if [ -n "$big_dirs" ]; then
  echo "ABORT: untracked directory larger than ${BIG_DIR_MB}MB present."
  echo "  gitignore it, or move it out of the checkout, then re-run:"
  echo "$big_dirs"
  exit 1
fi

if [ -z "$(git status --porcelain)" ]; then
  echo "no changes"
  exit 0
fi

git add -A -- . "${EXCLUDES[@]}"

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

if [ -z "$(git diff --cached --name-only)" ]; then
  echo "nothing to commit after exclusions"
  exit 0
fi

staged=$(git diff --cached --name-only | wc -l)
git -c i18n.commitEncoding=UTF-8 commit -q -m "自动快照 $(date '+%F %T')（${staged} 个文件）" \
  && echo "committed $(git rev-parse --short HEAD) ($staged files)"
git diff --cached --name-only HEAD~1 | sed 's/^/  staged: /'
if git push -q origin "$BRANCH"; then
  echo "pushed -> origin/$BRANCH"
else
  echo "PUSH FAILED"
  exit 1
fi