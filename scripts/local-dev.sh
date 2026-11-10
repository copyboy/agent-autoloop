#!/bin/sh
# 启动隔离的 dev 实例：默认 ~/.agent-autoloop-dev，端口 3351。
# 不碰生产 ~/.agent-autoloop。首次运行自动 init（--no-service，零 token 的 cat agent）。
set -eu
cd "$(dirname "$0")/.."

# 固定 Node 24：.nvmrc 是给 nvm 用的；脚本自己也兜底，避免 shell 里是 22 时装错版本。
NODE24="$HOME/.nvm/versions/node/v24.18.0/bin"
if [ ! -x "$NODE24/node" ]; then
  echo "找不到 Node 24.18.0（$NODE24）。先 nvm install 24.18.0，或改这个脚本里的路径。" >&2
  exit 1
fi
export PATH="$NODE24:$PATH"
case "$(node -v)" in
  v24.*) ;;
  *) echo "Node 版本不对：$(node -v)，需要 24.x" >&2; exit 1 ;;
esac
export AGENT_AUTOLOOP_HOME="${AGENT_AUTOLOOP_HOME:-$HOME/.agent-autoloop-dev}"

if [ ! -d node_modules ]; then
  echo "缺少依赖，先运行：pnpm install --frozen-lockfile" >&2
  exit 1
fi
PORT="${AGENT_AUTOLOOP_PORT:-3351}"

if [ ! -f "$AGENT_AUTOLOOP_HOME/config.json" ]; then
  echo "初始化隔离环境：${AGENT_AUTOLOOP_HOME}（端口 ${PORT}）"
  node bin/agent-autoloop.ts init --no-service --port "$PORT" --command 'cat {prompt}'
fi

echo "启动 dev hub：${AGENT_AUTOLOOP_HOME}"
echo "生产 ~/.agent-autoloop 不受影响；Ctrl+C 停。"
exec node bin/agent-autoloop.ts up
