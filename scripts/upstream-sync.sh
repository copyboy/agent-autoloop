#!/bin/sh
# 按 release tag 同步上游。默认干跑；--apply 才 rebase 并跑测试。
set -eu
cd "$(dirname "$0")/.."
git fetch upstream --tags --prune

LATEST="$(git tag --sort=-v:refname | head -1)"
BASE="$(git describe --tags --abbrev=0 gerrad/main 2>/dev/null || echo none)"

echo "本地分支：$(git branch --show-current)"
echo "本地基线：$BASE"
echo "上游最新：$LATEST"

if [ "$LATEST" = "$BASE" ]; then
  echo "已是最新。"
  exit 0
fi

echo
echo "上游自 $BASE 以来的改动："
git log --oneline "$BASE..$LATEST" | head -40
echo
echo "本地相对基线的提交："
git log --oneline "$BASE..gerrad/main" | head -40
echo

if [ "${1:-}" != "--apply" ]; then
  echo "干跑结束。执行 ./scripts/upstream-sync.sh --apply 把 gerrad/main rebase 到 $LATEST 并跑测试。"
  exit 0
fi

echo "rebase 到 $LATEST …"
git rebase "$LATEST"

export PATH="$HOME/.nvm/versions/node/v24.18.0/bin:$PATH"
pnpm import
pnpm install --frozen-lockfile
pnpm typecheck
pnpm test:quick
echo "pnpm-lock.yaml 有变化就一起提交：$(git status --short pnpm-lock.yaml || true)"

echo "完成：gerrad/main 已 rebase 到 $LATEST。"
