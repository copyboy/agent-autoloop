#!/bin/sh
# 给 autoloop 接另一个飞书租户，或切换当前的飞书通道。
#
# 只改 AGENT_AUTOLOOP_HOME（默认 ~/.agent-autoloop-dev）里的配置，不碰全局默认 profile，
# 也不碰生产 ~/.agent-autoloop。
#
# 用法：
#   LARK_APP_SECRET='...' ./scripts/lark-tenant.sh add <profile> <app-id>
#   ./scripts/lark-tenant.sh use <profile> <open-id>
#   ./scripts/lark-tenant.sh status <profile>
#
# 前提：新租户里已有一个自建应用，开了机器人能力，订阅 card.action.trigger（长连接）。
set -eu
cd "$(dirname "$0")/.."

export PATH="$HOME/.nvm/versions/node/v24.18.0/bin:$PATH"
HOME_DIR="${AGENT_AUTOLOOP_HOME:-$HOME/.agent-autoloop-dev}"
CONFIG="$HOME_DIR/config.json"
RULES="$HOME_DIR/rules.json"
PROGRAM="$PWD/bin/agent-autoloop.ts"

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
}

[ $# -ge 1 ] || usage
cmd="$1"; shift

case "$cmd" in
  add)
    [ $# -eq 2 ] || usage
    profile="$1"; appid="$2"
    if [ -z "${LARK_APP_SECRET:-}" ]; then
      echo "缺少 LARK_APP_SECRET：不要把 secret 写进命令行，用环境变量传。" >&2
      echo "  LARK_APP_SECRET='...' $0 add $profile $appid" >&2
      exit 1
    fi
    printf '%s' "$LARK_APP_SECRET" | lark-cli profile add \
      --name "$profile" --app-id "$appid" --brand feishu --app-secret-stdin
    echo "profile 已添加：$profile（没有切换全局默认 profile）"
    lark-cli auth status --profile "$profile" 2>&1 | head -20
    echo
    echo "下一步：用新租户账号扫码授权，拿 open_id："
    echo "  lark-cli auth login --profile $profile --no-wait"
    ;;

  use)
    [ $# -eq 2 ] || usage
    profile="$1"; open_id="$2"
    lark-cli auth status --profile "$profile" >/dev/null 2>&1 || {
      echo "profile 不可用：$profile（先跑 add）" >&2; exit 1;
    }
    wrapper="$PWD/scripts/lark-$profile"
    cat > "$wrapper" <<EOF
#!/bin/sh
exec lark-cli --profile $profile "\$@"
EOF
    chmod +x "$wrapper"

    [ -f "$CONFIG" ] || { echo "缺少 $CONFIG（先 pnpm run dev 初始化）" >&2; exit 1; }
    [ -f "$RULES" ] || { echo "缺少 $RULES" >&2; exit 1; }

    python3 - "$CONFIG" "$RULES" "$wrapper" "$open_id" "$PROGRAM" "$HOME_DIR" <<'PY'
import json, shutil, subprocess, sys
from pathlib import Path

config_path, rules_path, wrapper, open_id, program, home = sys.argv[1:7]
config = json.loads(Path(config_path).read_text())
channels = config.setdefault("channels", {})
feishu = channels.get("feishu", {})
# 只换接收人/程序，保留已有通道密钥；没有就生成一个
key = feishu.get("key")
if not key:
    out = subprocess.run(
        ["node", program, "key", "new", "channel", "feishu"],
        capture_output=True, text=True, env={**__import__("os").environ, "AGENT_AUTOLOOP_HOME": home},
    )
    for token in out.stdout.replace("：", " ").split():
        if len(token) >= 30:
            key = token
            break
    if not key:
        sys.exit("无法生成通道密钥：" + (out.stderr or out.stdout))
feishu.update({"key": key, "user": open_id, "lark": wrapper})
channels["feishu"] = feishu

rules = json.loads(Path(rules_path).read_text())
rules.setdefault("channels", {})["feishu"] = {"name": "飞书", "answerers": [open_id]}
# 只替换 feishu，保留 desktop 等其它通道

for path in (config_path, rules_path):
    shutil.copy2(path, path + ".bak")
Path(config_path).write_text(json.dumps(config, ensure_ascii=False, indent=2) + "\n")
Path(rules_path).write_text(json.dumps(rules, ensure_ascii=False, indent=2) + "\n")
print(f"已切换：feishu → profile wrapper {wrapper}")
print("旧通道配置已备份为 *.bak，可回滚。")
PY

    echo
    echo "重启 dev："
    echo "  pnpm run dev"
    echo "  AGENT_AUTOLOOP_HOME=$HOME_DIR agent-autoloop doctor   # 应显示 飞书在线"
    ;;

  status)
    [ $# -eq 1 ] || usage
    lark-cli auth status --profile "$1"
    ;;

  *)
    usage
    ;;
esac
