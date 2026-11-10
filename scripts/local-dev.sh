#!/bin/sh
# 启动隔离的 dev 实例：默认 ~/.agent-autoloop-dev，端口 3351。
# 不碰生产 ~/.agent-autoloop。首次运行自动 init（--no-service，零 token 的 cat agent）。
set -eu
cd "$(dirname "$0")/.."
export PATH="$HOME/.nvm/versions/node/v24.18.0/bin:$PATH"
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
