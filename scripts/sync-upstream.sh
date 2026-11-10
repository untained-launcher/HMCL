#!/usr/bin/env bash
# 按 merge 方式跟随上游：本 fork 的历史 = 上游历史 + 本 fork 的提交。
#
# 上游提交以原 SHA 合并进历史，不再逐条重放；同步只需合并一次。
# 合并后强制应用 fork 的配置：
#   - `.github/sync-protected-paths.txt` 里的文件恢复为 fork 版本；
#   - `.github/sync-removed-paths.txt` 里的路径保持删除。
# 其余冲突一律中止并交人工处理，避免悄悄丢上游改动。
#
# 环境变量：
#   UPSTREAM_REPO / UPSTREAM_URL / UPSTREAM_BRANCH / TARGET_BRANCH
#   DRY_RUN=true 只合并不推送（人工预演）
set -euo pipefail

UPSTREAM_REPO="${UPSTREAM_REPO:-HMCL-dev/HMCL}"
UPSTREAM_URL="${UPSTREAM_URL:-https://github.com/${UPSTREAM_REPO}.git}"
UPSTREAM_BRANCH="${UPSTREAM_BRANCH:-main}"
TARGET_BRANCH="${TARGET_BRANCH:-main}"

OWNED_LIST=".github/sync-protected-paths.txt"
REMOVED_LIST=".github/sync-removed-paths.txt"

read_list() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  grep -vE '^[[:space:]]*(#|$)' "$file" || true
}

contains() {
  local needle="$1"
  shift
  local x
  for x in "$@"; do [[ "$x" == "$needle" ]] && return 0; done
  return 1
}

# 目录条目用前缀匹配，文件名用全等。
matches_removed() {
  local f="$1" p
  for p in "${REMOVED[@]}"; do
    [[ "$f" == "$p" || "$f" == "$p"/* ]] && return 0
  done
  return 1
}

mapfile -t OWNED < <(read_list "$OWNED_LIST")
mapfile -t REMOVED < <(read_list "$REMOVED_LIST")

git config user.name "${SYNC_GIT_NAME:-github-actions[bot]}"
git config user.email "${SYNC_GIT_EMAIL:-41898282+github-actions[bot]@users.noreply.github.com}"
git config commit.gpgsign false

# 合并前快照 fork 自有文件，合并后原样写回。
OVERRIDE_DIR="$(mktemp -d)"
trap 'rm -rf "$OVERRIDE_DIR"' EXIT
for f in "${OWNED[@]}"; do
  if git cat-file -e "HEAD:${f}" 2>/dev/null; then
    mkdir -p "${OVERRIDE_DIR}/$(dirname "$f")"
    git show "HEAD:${f}" >"${OVERRIDE_DIR}/${f}"
  fi
done

git remote add upstream "$UPSTREAM_URL" 2>/dev/null || true
git remote set-url upstream "$UPSTREAM_URL"
git fetch --no-tags upstream "$UPSTREAM_BRANCH"

UPSTREAM_REF="upstream/${UPSTREAM_BRANCH}"
UPSTREAM_SHA="$(git rev-parse "$UPSTREAM_REF")"

if git merge-base --is-ancestor "$UPSTREAM_SHA" HEAD; then
  echo "[sync] 上游无新提交（${UPSTREAM_SHA:0:10}）"
  echo "changed=false" >>"${GITHUB_OUTPUT:-/dev/null}"
  exit 0
fi

BEHIND="$(git rev-list --count "HEAD..${UPSTREAM_SHA}")"
echo "[sync] 合并上游 ${UPSTREAM_SHA:0:10}（${BEHIND} 个提交）"

# --no-ff 保证总产生 merge commit，后面的配置修正可以 amend 进去。
if ! git merge --no-ff --no-edit "$UPSTREAM_REF"; then
  mapfile -t conflicts < <(git diff --name-only --diff-filter=U)
  echo "[sync] 冲突 ${#conflicts[@]} 个，按 fork 清单裁决"

  unresolved=()
  for f in "${conflicts[@]}"; do
    if contains "$f" "${OWNED[@]}"; then
      git checkout --ours -- "$f" && git add "$f"
      echo "  保留本 fork 版本：$f"
    elif matches_removed "$f"; then
      git rm -q --force --ignore-unmatch -- "$f" || git add -A -- "$f"
      echo "  保持删除：$f"
    else
      unresolved+=("$f")
    fi
  done

  if ((${#unresolved[@]} > 0)); then
    echo "[sync] 以下冲突无法按既定清单裁决，中止合并，交人工处理："
    printf '  %s\n' "${unresolved[@]}"
    git merge --abort || true
    exit 1
  fi

  git -c commit.gpgsign=false commit --no-edit
fi

# 合并后强制应用 fork 配置：上游对自有文件的改动、以及上游新增的被移除路径，
# 都不会进入本仓库。
for f in "${OWNED[@]}"; do
  [[ -f "${OVERRIDE_DIR}/${f}" ]] || continue
  mkdir -p "$(dirname "$f")"
  cp "${OVERRIDE_DIR}/${f}" "$f"
  git add -- "$f"
done

for p in "${REMOVED[@]}"; do
  if git cat-file -e "HEAD:${p}" 2>/dev/null || [[ -e "$p" ]]; then
    if [[ -d "$p" ]]; then
      git rm -r -q --force --ignore-unmatch -- "$p" || true
    else
      git rm -q --force --ignore-unmatch -- "$p" || true
    fi
  fi
done

if ! git diff --cached --quiet; then
  echo "[sync] 修正 fork 自有配置"
  git -c commit.gpgsign=false commit --amend --no-edit
fi

if [[ "${DRY_RUN:-}" == "true" ]]; then
  echo "[sync] DRY_RUN：已合并到本地，跳过推送（HEAD $(git rev-parse --short HEAD)）"
  exit 0
fi

git push origin "HEAD:${TARGET_BRANCH}"
echo "[sync] 完成：HEAD $(git rev-parse --short HEAD)"
echo "changed=true" >>"${GITHUB_OUTPUT:-/dev/null}"
