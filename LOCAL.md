# LOCAL · 这个 fork 怎么用

这是 `agent-autoloop` 的本地 fork，基线 **v1.7.1**（2026-11-09）。
目的：在它的调度内核之上迭代我们自己的事件源、Agent 和通道，同时保持能跟上游合并。

## 分支与远程

| 名称 | 用途 |
|---|---|
| `main` | 上游镜像。**只 fetch，不提交。** |
| `gerrad/main` | 本地主线。所有本地改动在这里。 |
| `upstream` | `https://github.com/KKKKhazix/agent-autoloop.git` |

还没建 GitHub fork。建好后：

```bash
git remote add origin git@github.com:<你>/agent-autoloop.git
git push -u origin gerrad/main
```

## 本地改动的边界

1. **优先落在 `plugins/`**：事件源、Agent、通道都按上游约定写插件，不碰 `kernel/` / `protocol/` / `worker/`。
2. **不改协议**。真要改，先按上游 `docs/protocol.md` 的兼容规则写清。
3. **不加界面**。上游明确「中台没有界面」；看板放工作台仓库，读 `/v1/state` 或 `/v1/stream`。
4. **零运行时依赖**。`package.json` 不写 `dependencies`。
5. **测试先行**：每个行为一条测试，新测试先写它防的失败方式。
6. 本地文档放 `LOCAL.md`、`docs/ROADMAP.md`、`examples/recipes/`；不改上游 README 的口径。

## 开发环境

Node 24（本机 `~/.nvm/versions/node/v24.18.0`）：

```bash
nvm use                          # .nvmrc = 24.18.0
pnpm install --frozen-lockfile   # 本 fork 用 pnpm（见下）
pnpm typecheck
pnpm test:quick                  # 707 pass / 19 skip 是当前基线
```

开发实例：`pnpm run dev`（等价 `./scripts/local-dev.sh`；脚本会强制用 Node 24.18.0，即使当前 shell 是 22）。

### 包管理器：pnpm，但保留上游 lock

- 上游的 `package-lock.json` **不动**（上游权威，CI 用 npm）。
- 本地用 `pnpm import` 从它生成 `pnpm-lock.yaml`，再 `pnpm install --frozen-lockfile`。
- 两个 lock 都提交；**不要手改** `pnpm-lock.yaml`，改依赖后重新 import。
- 上游同步脚本会自动重新 import。

## 隔离运行（不碰生产）

生产实例是 `~/.agent-autoloop`（端口 3350）。开发实例默认：
`~/.agent-autoloop-dev`（端口 3351）。

```bash
./scripts/local-dev.sh          # 首次会自动 init（--no-service），然后前台 up
AGENT_AUTOLOOP_HOME=/tmp/al-dev ./scripts/local-dev.sh
```

dev 实例用 `cat {prompt}` 当 Agent，零 token，只验证链路。

## 上游同步

```bash
./scripts/upstream-sync.sh                 # 干跑：只 fetch + 列出新版本与改动
./scripts/upstream-sync.sh --apply         # rebase 到最新 tag，跑 typecheck + test:quick
```

策略：

- **按 release tag 同步**，不跟 `main`（`main` 有未发布改动）。
- 本地提交保持小而扁：一个迭代一个 commit，尽量只动 `plugins/`，冲突时以上游为准，再把插件补回去。
- 每次同步后必须跑 `pnpm typecheck && pnpm test:quick`。

## 部署

本地验证通过后，两种方式二选一：

1. 直接指向源码：`node ~/Workspace/agent-autoloop/bin/agent-autoloop.ts up`
2. 部署到生产目录（会覆盖）：`rsync -a --exclude .git --exclude node_modules ~/Workspace/agent-autoloop/ ~/.agent-autoloop/app/`，然后重启服务。

生产数据（`~/.agent-autoloop` 的 `hub.db` / `config.json` / `secrets.env`）**不在仓库里**，不要提交、不要覆盖。
