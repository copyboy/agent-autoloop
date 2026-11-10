# 本地迭代计划（gerrad fork）

> 基线 v1.7.1。原则：**内核不动，价值加在插件和配方上**；每个迭代都要能在隔离 dev 实例里跑通，并且不破坏上游合并。

## P0 · 工程基线（已完成）

- [x] 本地 fork：`main` 镜像上游，`gerrad/main` 本地主线，`upstream` 远程。
- [x] Node 24 开发环境；`typecheck` + `test:quick` 通过（707 pass / 19 skip）。
- [x] `scripts/local-dev.sh`：隔离 `~/.agent-autoloop-dev` + 端口 3351，零 token `cat` agent。
- [x] `scripts/upstream-sync.sh`：按 tag 同步 + 干跑 diff + 可选 rebase + 测试。

**验收**：`./scripts/local-dev.sh` 起得来，生产 `~/.agent-autoloop` 不受影响。

## P1 · 第一个本地插件：`workbench` 事件源

把工作台的真实信号变成 autoloop 事件，跑通「信号 → 规则 → Agent → 卡片」。

- `plugins/workbench/source.ts`
  - 读 `signals/projects.json` + `signals/sessions.json`（只读）
  - 转成事件：`workbench.signal`，`subject` = 项目名，`summary` = 一句话
  - 去重：同一项目同一 signal id 只发一次（用事件的 `id`）
- 配方 `examples/recipes/workbench-daily/`
  - 规则：每天 08:50 跑 `scan + signals`，把「未结论 / 脏 / 长期未动」变成事件
  - Agent：`command` 型，跑一个只读脚本产出 3 行摘要
  - 通道：桌面通知
- 测试：`plugins` 的 source 单元测试 + 一次 dev 实例端到端（假 agent）

**验收**：dev 实例里 1 条事件 → Agent → 桌面卡片；重复事件不重复发。

**边界**：source 只读文件；不写项目目录；不做界面。

## P2 · 每日矩阵摘要（配方，不写内核）

- 规则 `daily-matrix`：cron 08:50，`cwd` 指向工作台仓库，跑 `npm run scan && npm run signals`
- Agent 产出：3 行「今天值得看」摘要（未结论 Top3 / 脏 / 30d 未动数）
- 失败态：采集失败也要发卡片说明，不静默

**验收**：连续 3 天早上自动出一张卡片；失败时也有一张失败卡。

## P3 · 只读观察客户端（不放进本仓库）

- 工作台 `site/` 读 `/v1/state`，显示 runs / cards / 今日轮次
- 不做写操作；卡片回答仍走 CLI / 飞书

**验收**：矩阵页能看到 autoloop 在线与最近轮次，不需要额外服务。

## P4 · 回馈上游

把通用能力提 PR，本地只留私有部分：

- `workbench` source 若足够通用 → 提上游
- 上游同步脚本只是本地工具，不提
- 每次同步后记录冲突点，超过 3 次冲突的本地改动重新考虑归属

## 不做什么

- 不改 `kernel/` 的事件/事务语义
- 不加界面、不做「大屏」
- 不引入运行时依赖
- 不做数据迁移（上游用事实日志重建）
- 不把生产数据（hub.db / config / secrets）放进仓库
