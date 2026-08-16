#!/usr/bin/env bash
#
# check-upstream.sh — 检查 readonly-dependencies 下依赖项目的上游更新(通用)
#
# 用法:
#   bash ai/config/scripts/check-upstream.sh [项目名]
#   缺省取 readonly-dependencies 下排序后的第一个项目
#
# 双锚点设计 (记录文件 ai/output/upstream/<项目名>.md):
#   baseline:   人工维护的代码同步点("我的改造基于哪个版本")
#   last-check: 脚本维护的上次观察点("上次看到上游到哪"), 每次观察到新版本即自动前移
#
# 决策约定: 跟进完成 = git pull + 回写 baseline; 跳过 = baseline 不动(待跟进数持续累计),
# 跳过理由可写在模块移植 commit message 中
#
# 行为:
#   1. 定位项目目录, 从其 git 配置读取 remote url 与当前分支(脚本内不写死 git 信息)
#   2. git fetch(只更新 .git 引用, 不动工作区)
#   3. FETCH_HEAD == last-check -> [OK] 上游无更新; 记录文件不存在则先生成初始骨架
#   4. 本地已 pull 到最新但 baseline 未回写 -> [OK] + 提示回写, 静默前移 last-check
#   5. 否则(有新更新): 生成骨架(若不存在), 追加检查记录(自上次检查的增量), 前移 last-check,
#      输出新增 commit / 距基线 diff 概览 / compare 链接
#
# 注意: 只自动维护 last-check 行与"检查记录"小节; baseline 行由人工维护。

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
LOCAL_HEAD="$(git -C "$REPO_DIR" rev-parse HEAD)"

# 拼 compare 链接用 web url: git@host:org/repo.git -> https://host/org/repo
if [[ "$REMOTE_URL" == git@* ]]; then
  TMP="${REMOTE_URL#git@}"
  TMP="${TMP%.git}"
  WEB_URL="https://${TMP%%:*}/${TMP#*:}"
else
  WEB_URL="${REMOTE_URL%.git}"
fi

# ---------- 解析双锚点 ----------
BASELINE=""
LASTCHECK=""
if [[ -f "$UPSTREAM_FILE" ]]; then
  BASELINE="$(grep -E '^baseline:[[:space:]]*[0-9a-f]{7,40}' "$UPSTREAM_FILE" | head -1 | awk '{print $2}' || true)"
  [[ -z "$BASELINE" ]] && echo "warn: $UPSTREAM_FILE 中无 baseline: 行, 回退为本地 HEAD" >&2
  LASTCHECK="$(grep -E '^last-check:[[:space:]]*[0-9a-f]{7,40}' "$UPSTREAM_FILE" | head -1 | awk '{print $2}' || true)"
else
  echo "提示: 基线文件不存在 (首次运行), 稍后自动生成初始记录文件" >&2
fi
if [[ -z "$BASELINE" ]]; then
  BASELINE="$LOCAL_HEAD"
fi
if [[ -z "$LASTCHECK" ]]; then
  LASTCHECK="$BASELINE"
fi

# ---------- fetch (只更新 .git, 工作区不受影响) ----------
echo ">> [$PROJECT] git fetch origin/$BRANCH ..."
if ! git -C "$REPO_DIR" fetch origin "$BRANCH"; then
  echo "error: fetch 失败(检查网络/remote)" >&2
  exit 1
fi

LATEST="$(git -C "$REPO_DIR" rev-parse FETCH_HEAD)"

echo
echo "项目     : $PROJECT"
echo "remote   : $REMOTE_URL"
echo "分支     : $BRANCH"
echo "基线     : $BASELINE"
echo "上次检查 : $LASTCHECK"
echo "最新     : $LATEST ($(git -C "$REPO_DIR" log -1 --format='%ci' FETCH_HEAD))"

# 将记录文件中的 last-check 行前移到指定 hash (无该行则插到 baseline 行之后)
advance_lastcheck() {
  local file="$1" hash="$2"
  if grep -qE '^last-check:' "$file"; then
    awk -v h="$hash" '/^last-check:/{print "last-check: " h; next} {print}' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
  elif grep -qE '^baseline:' "$file"; then
    awk -v h="$hash" '/^baseline:/{print; print "last-check: " h; next} {print}' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
  else
    { printf 'last-check: %s\n' "$hash"; cat "$file"; } > "$file.tmp" && mv "$file.tmp" "$file"
  fi
}

# 生成记录骨架 (文件不存在时); 参数: $1=baseline $2=last-check
write_skeleton() {
  mkdir -p "$UPSTREAM_DIR"
  cat > "$UPSTREAM_FILE" <<EOF
# $PROJECT 上游跟进记录

baseline: $1
last-check: $2

> baseline 行人工维护: 跟进完成(git pull)后更新为新 hash
> last-check 行由脚本自动维护, 请勿手工编辑

## 检查记录 (脚本自动追加)

EOF
}

# ---------- 对比 ----------
if [[ "$LATEST" == "$LASTCHECK" ]]; then
  echo
  echo "[OK] 上游无更新"
  if [[ ! -f "$UPSTREAM_FILE" ]]; then
    write_skeleton "$BASELINE" "$LATEST"
    echo "已生成初始记录文件: $UPSTREAM_FILE"
  fi
  if [[ "$BASELINE" != "$LATEST" ]]; then
    PENDING="$(git -C "$REPO_DIR" rev-list --count "$BASELINE..$LATEST")"
    echo "提示: 距基线 ${BASELINE:0:7} 仍有 ${PENDING} 个 commit 未跟进: $WEB_URL/compare/$BASELINE...$BRANCH"
  fi
  exit 0
fi

# 本地已 pull 到最新, 但 baseline 未回写: 不记增量, 静默前移 last-check 并提示
if [[ "$LOCAL_HEAD" == "$LATEST" && "$BASELINE" != "$LATEST" && -f "$UPSTREAM_FILE" ]]; then
  advance_lastcheck "$UPSTREAM_FILE" "$LATEST"
  echo
  echo "[OK] 本地已同步到最新, 但 baseline 仍为 ${BASELINE:0:7}"
  echo "提示: 若已完成全量跟进, 请将 $UPSTREAM_FILE 中 baseline 回写为 $LATEST"
  exit 0
fi

# ---------- 有更新: 写检查记录并前移 last-check ----------
COUNT_INC="$(git -C "$REPO_DIR" rev-list --count "$LASTCHECK..FETCH_HEAD")"
COUNT_TOTAL="$(git -C "$REPO_DIR" rev-list --count "$BASELINE..FETCH_HEAD")"
NOW="$(date '+%Y-%m-%d %H:%M')"
COMPARE_INC_URL="$WEB_URL/compare/$LASTCHECK...$BRANCH"
RECORD="- $NOW | ${LASTCHECK:0:7} → ${LATEST:0:7} | ${COUNT_INC} 个新 commit (距基线累计 ${COUNT_TOTAL}) | $COMPARE_INC_URL"

if [[ ! -f "$UPSTREAM_FILE" ]]; then
  write_skeleton "$BASELINE" "$LATEST"
else
  advance_lastcheck "$UPSTREAM_FILE" "$LATEST"
fi
printf '%s\n' "$RECORD" >> "$UPSTREAM_FILE"

echo
echo "=== 上游有更新: 自上次检查新增 commit ==="
git -C "$REPO_DIR" log --oneline "$LASTCHECK..FETCH_HEAD"

echo
echo "=== 待跟进代码变更概览 (自基线, 共 ${COUNT_TOTAL} commit, lib 或 src) ==="
git -C "$REPO_DIR" diff --stat "$BASELINE" FETCH_HEAD -- lib src

echo
echo "=== 详情链接 ==="
echo "增量: $COMPARE_INC_URL"
echo "全量: $WEB_URL/compare/$BASELINE...$BRANCH"
echo
echo "提醒: 跟进完成: git -C \"$REPO_DIR\" pull 并回写 $UPSTREAM_FILE 中 baseline;"
echo "      跳过: baseline 不动(待跟进数持续累计)。"
