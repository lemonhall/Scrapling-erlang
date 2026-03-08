# Agent Notes: Scrapling-erlang

## Project Overview

`Scrapling-erlang` 是本机项目 `E:\development\Scrapling` 的 Erlang/OTP 对等实现仓库。

当前阶段：

- **2026-03-08**：已完成 `v1-repo-bootstrap`，仓库具备最小 Erlang 骨架、环境脚本与 bootstrap eunit
- 源项目快照版本：`0.4.1`
- 目标：按 `docs/prd/PRD-0001-scrapling-parity.md` 与 `docs/plan/v1-index.md` 做能力对等复刻

## Quick Commands

前置环境：

- Erlang/OTP 28
- `rebar3`
- Windows PowerShell 7.x（必须显式用 `pwsh.exe`）
- 中国大陆网络环境通常需要代理

当前仓库已经完成 bootstrap，下面这些命令可直接作为本地开发入口：

- 设置环境（无代理）：`. .\scripts\erlang-env.ps1 -SkipRebar3Verify`
- 设置环境（带代理）：`. .\scripts\erlang-env.ps1 -EnableProxy -SkipRebar3Verify`
- 跑最小测试：`rebar3 eunit -m scrapling_bootstrap_tests`
- 跑全量单测：`rebar3 eunit`
- 启动 shell：`rebar3 shell`

## Shell Gate

- 在本仓库中，**必须显式使用** `pwsh.exe`
- 不得回退到 `powershell.exe` 5.x，即便只是读文件
- 涉及仓库文本写入时，优先用 `apply_patch` 或 Python `Path.write_text(..., encoding='utf-8', newline='\n')`

## Source of Truth

- 源项目仓库：`E:\development\Scrapling`
- 愿景文档：`docs/prd/VISION.md`
- 主 PRD：`docs/prd/PRD-0001-scrapling-parity.md`
- 当前执行索引：`docs/plan/v1-index.md`

如果源项目、计划文档、代码实现三者出现冲突，按以下顺序处理：

1. 用户明确新指令
2. 本仓 PRD / ECN
3. 本仓 vN 计划
4. 源项目当前实现与文档

不得口头修改范围后继续施工，必须留痕。

## Intended Repository Layout

- `apps/scrapling/src/`：Erlang 源码
- `apps/scrapling/test/`：eunit 与场景级测试
- `apps/scrapling/priv/`：运行时资源 / fixture / 适配器脚本
- `scripts/`：PowerShell 启动、校验、E2E 脚本
- `docs/prd/`：愿景、PRD
- `docs/plan/`：版本化计划与追溯矩阵
- `docs/ecn/`：设计变更单

## Architecture Direction

在没有 ECN 之前，默认架构方向如下：

- **解析层**：纯 Erlang 优先，暴露 `scrapling_selector*` 模块族
- **HTTP 抓取层**：适配器边界清晰，避免把具体 HTTP 客户端类型泄漏到公开 API
- **浏览器抓取层**：优先采用 Port / sidecar 方式接 Playwright / CDP，不走 NIF-first 路线
- **Spider 层**：基于 OTP 进程、消息传递、磁盘 checkpoint、可恢复调度
- **CLI / MCP 层**：提供 Erlang 侧命令入口与对外协议适配，不允许仅靠 README 声称存在

## Working Rules

- 直接在 `main` 上开发（当前仓无多人协作 / 无 worktree 要求）
- 每完成一个明确 slice，执行一次 `git add -A && git commit && git push`
- 不允许擅自打折“像素级复刻”目标
- 不允许把“计划里写了”当成“已经完成”
- 每次进入实现前，先更新追溯矩阵
- 为任何行为变更补测试，优先最小相关 eunit，再跑 `rebar3 eunit`
- 除非用户明确确认，否则不要执行危险删除操作
- 不要把密钥、token、代理口令写入仓库文件
- 尽量把缓存、构建产物、依赖目录留在 `E:`

## Parity Discipline

在宣称“已完成对等能力”之前，必须同时给出：

- 对应源项目路径
- 对应本仓 Req ID
- 对应本仓测试入口
- 最新验证命令输出

缺一项都不算完成。

## Completion Reminder

任务完成后，发送一条 APNs 简报：

- Title：`Scrapling-erlang`
- Body：不超过 10 个中文字符，且不含敏感信息

