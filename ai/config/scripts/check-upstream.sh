#!/usr/bin/env bash
#
# check-upstream.sh — 检查 readonly-dependencies 下依赖项目的上游更新(通用)
#
# 用法:
#   bash ai/config/scripts/check-upstream.sh [项目名]
#   缺省取 readonly-dependencies 下排序后的第一个项目
#
# 行为:
#   1. 定位项目目录, 从其 git 配置读取 remote url 与当前分支(脚本内不写死 git 信息)
#   2. 基线: ai/output/upstream/<项目名>.md 中 "baseline: <hash>" 行;
#      缺失时回退为本地克隆当前 HEAD(冻结版本即隐式基线), 并给出 warn
#   3. git fetch(只更新 .git 引用, 不动工作区)
#   4. 远端与基线一致 -> 提示无更新, 不写文件;
#      否则输出新增 commit / lib diff 概览 / compare 链接,
#      并自动追加一行检查记录到 ai/output/upstream/<项目名>.md (文件不存在则生成骨架)
#
# 注意: 除追加"检查记录"外不改文件; baseline 行与决策日志由人工维护。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
DEPS_DIR="$WORKSPACE_ROOT/readonly-dependencies"
UPSTREAM_DIR="$WORKSPACE_ROOT/ai/output/upstream"

# ---------- 定位项目 ----------
if [[ -n "${1:-}" ]]; then
  PROJECT="$1"
else
  PROJECT="$(find "$DEPS_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort | head -1)"
fi

REPO_DIR="$DEPS_DIR/$PROJECT"
UPSTREAM_FILE="$UPSTREAM_DIR/$PROJECT.md"

if [[ ! -d "$REPO_DIR" ]]; then
  echo "error: 项目目录不存在: $REPO_DIR" >&2
  exit 1
fi
if ! git -C "$REPO_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "error: $REPO_DIR 不是 git 仓库" >&2
  exit 1
fi

# ---------- 从 git 配置读取仓库信息 ----------
REMOTE_URL="$(git -C "$REPO_DIR" remote get-url origin)"
BRANCH="$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD)"

# 拼 compare 链接用 web url: git@host:org/repo.git -> https://host/org/repo
if [[ "$REMOTE_URL" == git@* ]]; then
  TMP="${REMOTE_URL#git@}"
  TMP="${TMP%.git}"
  WEB_URL="https://${TMP%%:*}/${TMP#*:}"
else
  WEB_URL="${REMOTE_URL%.git}"
fi

# ---------- 解析基线 ----------
BASELINE=""
if [[ -f "$UPSTREAM_FILE" ]]; then
  BASELINE="$(grep -E '^baseline:[[:space:]]*[0-9a-f]{7,40}' "$UPSTREAM_FILE" | head -1 | awk '{print $2}')"
  [[ -z "$BASELINE" ]] && echo "warn: $UPSTREAM_FILE 中无 baseline: 行, 回退为本地 HEAD" >&2
else
  echo "warn: 基线文件不存在: $UPSTREAM_FILE, 回退为本地 HEAD" >&2
fi
if [[ -z "$BASELINE" ]]; then
  BASELINE="$(git -C "$REPO_DIR" rev-parse HEAD)"
fi

# ---------- fetch (只更新 .git, 工作区不受影响) ----------
echo ">> [$PROJECT] git fetch origin/$BRANCH ..."
if ! git -C "$REPO_DIR" fetch origin "$BRANCH"; then
  echo "error: fetch 失败(检查网络/remote)" >&2
  exit 1
fi

LATEST="$(git -C "$REPO_DIR" rev-parse FETCH_HEAD)"

echo
echo "项目   : $PROJECT"
echo "remote : $REMOTE_URL"
echo "分支   : $BRANCH"
echo "基线   : $BASELINE"
echo "最新   : $LATEST ($(git -C "$REPO_DIR" log -1 --format='%ci' FETCH_HEAD))"

# ---------- 对比 ----------
if [[ "$LATEST" == "$BASELINE" ]]; then
  echo
  echo "[OK] 上游无更新"
  exit 0
fi

# ---------- 写检查记录 (仅有更新时) ----------
COUNT="$(git -C "$REPO_DIR" rev-list --count "$BASELINE..FETCH_HEAD")"
NOW="$(date '+%Y-%m-%d %H:%M')"
COMPARE_URL="$WEB_URL/compare/$BASELINE...$BRANCH"
RECORD="- $NOW | 基线 ${BASELINE:0:7} → 最新 ${LATEST:0:7} | ${COUNT} 个新 commit | $COMPARE_URL"

mkdir -p "$UPSTREAM_DIR"
if [[ ! -f "$UPSTREAM_FILE" ]]; then
  cat > "$UPSTREAM_FILE" <<EOF
# $PROJECT 上游跟进记录

baseline: $BASELINE

> baseline 行人工维护: 全量跟进并 git pull 后更新为新 hash

## 决策日志 (人工维护)

| 日期 | 范围 | 决策 | 理由 | 已移植项 |
|------|------|------|------|----------|

## 检查记录 (脚本自动追加)

EOF
fi
printf '%s\n' "$RECORD" >> "$UPSTREAM_FILE"

echo
echo "=== 上游有更新, 新增 commit ==="
git -C "$REPO_DIR" log --oneline "$BASELINE..FETCH_HEAD"

echo
echo "=== 代码变更概览 (lib 或 src) ==="
git -C "$REPO_DIR" diff --stat "$BASELINE" FETCH_HEAD -- lib src

echo
echo "=== 详情链接 ==="
echo "compare: $WEB_URL/compare/$BASELINE...$BRANCH"
echo
echo "提醒: 评估后在 $UPSTREAM_FILE 决策日志中记录 跟进/跳过 及理由;"
echo "      全量跟进完成后: git -C \"$REPO_DIR\" pull 并回写新 baseline。"
