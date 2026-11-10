# 换飞书租户（只保留新的）

目标：把工作台用的飞书通道从旧租户换成新租户；旧通道配置备份但不启用。
不碰全局默认 lark-cli profile（其它工具还在用），只给 autoloop 的 dev 实例指定新 profile。

## 0. 新租户里准备一个自建应用

在**新租户**的飞书开放平台创建「自建应用」，然后：

1. 开启**机器人**能力；
2. 事件订阅选**长连接**，订阅 `card.action.trigger`（卡片回传交互）；
3. 权限：至少 `im:message`（以机器人身份发消息）；
4. 拿到 **App ID / App Secret**。

如果还没有应用，也可以让 CLI 走浏览器创建（会阻塞，输出里给授权链接）：

```bash
lark-cli config init --new --name gerrad-lark2
```

## 1. 添加 profile（凭据不进命令行）

```bash
cd ~/Workspace/agent-autoloop
LARK_APP_SECRET='<新应用 secret>' ./scripts/lark-tenant.sh add gerrad-lark2 cli_xxxxxxxx
```

这一步只新增 profile，不切全局默认，不覆盖旧租户。

## 2. 拿新租户里的 open_id

```bash
lark-cli auth login --profile gerrad-lark2 --no-wait
# 打开输出的链接/二维码，用新租户账号授权
lark-cli auth status --profile gerrad-lark2   # identities.user.openId
```

> 发卡只需要 bot 身份；但通道要知道「发给谁」，所以必须有这个 open_id。
> 如果应用已经能拿到你的 open_id，也可以直接跳到第 3 步。

## 3. 切换 dev 实例的通道（只保留新的）

```bash
./scripts/lark-tenant.sh use gerrad-lark2 ou_新租户的openid
```

它做四件事：

- 生成 wrapper `scripts/lark-gerrad-lark2`（`lark-cli --profile gerrad-lark2 "$@"`）
- 把 `~/.agent-autoloop-dev/config.json` 的 `channels.feishu` 换成新 user + wrapper，
  **保留原通道密钥**（不重新发密钥）
- 把 `rules.json` 的 `channels.feishu.answerers` 换成新 open_id
- 备份原配置为 `*.bak`

旧的 lark-cli profile 仍在，但 autoloop 不再使用它。想回滚：把 `*.bak` 拷回去，重启。

## 4. 重启并验证

```bash
lark-cli event stop 2>/dev/null || true      # 释放旧的长连接（如果有）
pnpm run dev
AGENT_AUTOLOOP_HOME="$HOME/.agent-autoloop-dev" agent-autoloop doctor
# 应显示：飞书在线
```

发一张测试卡：`try`（会走 Claude，约 $0.12），或等下一次真实卡片。
在**新租户**的飞书里应该收到卡片；点按钮后 `status` 会显示回答、`why` 能看到接回原会话。

## 注意

- 一个飞书应用只能有一个 `card.action.trigger` 长连接监听；新旧应用不要同时接。
- 别把 App Secret 写进命令历史；用环境变量（脚本只从 `LARK_APP_SECRET` 读）。
- 生产实例 `~/.agent-autoloop` 不受影响；本流程只动 dev。
