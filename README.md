# Scrapling-erlang

`Scrapling-erlang` 的目标，是把本机源码仓 `E:\development\Scrapling` 在 **Erlang/OTP** 上做成能力对等实现。

当前时间点是 **2026-03-08**，本仓库已完成 **bootstrap + parser/adaptive 基础切片 + static fetcher/session/proxy rotator + browser sidecar/dynamic fetcher/dynamic session/stealth fetcher/stealth session 首轮切片 + browser contract 校验补强 + spider 最小串行 crawl + checkpoint/pause/resume/stream/blocked retry 首轮闭环**，并已通过当前全量 `eunit` 门禁。

## 当前状态

- 源项目基线：本机 `E:\development\Scrapling`
- 源项目版本快照：`scrapling/__init__.py` 显示 `0.4.1`
- 当前仓状态：已建立 `rebar3` 骨架、selector/selectors/adaptive 存储、静态 fetcher/session/proxy rotation、browser sidecar/dynamic fetcher/dynamic session/stealth fetcher/stealth session、本地 HTTP fixture server、`cdp_url` 最小契约校验、`wait_selector_state` 四态语义、browser session 错误隔离、`blocked_domains` 目标域拦截契约，以及 spider `Request` / `Scheduler` / `SessionManager` / `CrawlerEngine` / `Spider` / `Checkpoint` / `pause` / `resume` / `stream` / `blocked retry` / 外部 `pause` 信号最小闭环，与 `68` 条 eunit 测试闭环
- 默认目标：让 **Erlang / BEAM 社区** 获得与源项目等价的解析、抓取、蜘蛛、CLI、AI/MCP 能力
- 最新 Spider slice：已补齐 `run/2`、`pause/1`、`await/2` 外部控制入口，并对齐“有 checkpoint 则 paused，无 checkpoint 则优雅停止”的语义

## 文档入口

- 愿景：`docs/prd/VISION.md`
- 主 PRD：`docs/prd/PRD-0001-scrapling-parity.md`
- v1 总索引：`docs/plan/v1-index.md`
- v1 仓库基建计划：`docs/plan/v1-repo-bootstrap.md`
- v1 解析器计划：`docs/plan/v1-parser-adaptive.md`
- v1 静态抓取计划：`docs/plan/v1-fetchers-static.md`
- v1 浏览器抓取计划：`docs/plan/v1-fetchers-browser.md`
- v1 Spider 运行时计划：`docs/plan/v1-spider-runtime.md`
- v1 CLI / AI / 文档计划：`docs/plan/v1-cli-ai-docs.md`

## 交付原则

- 默认直接在 `main` 上推进
- 每完成一个清晰 slice，就执行一次 `commit + push`
- 不允许擅自降低“像素级复刻”的要求
- 不允许把“写了文档”当成“功能已实现”
- 不允许先实现再回填追溯矩阵
- 每一项源项目公开能力都必须进入：`PRD → v1 计划 → 测试入口 → 证据`

## 下一步

当前阶段已经完成文档矩阵、bootstrap、静态抓取，以及 Spider runtime 的 pause / resume / checkpoint / stream / blocked retry 主链路，接下来优先回到浏览器能力面：

1. 继续 `docs/plan/v1-fetchers-browser.md`，补 `page_action`、子资源拦截与真实 `cdp_url` 接管
2. 继续提升 Spider runtime 的更高阶 parity（如更完整并发/导出/观测口径）
3. 持续更新 `docs/plan/v1-index.md` 的追溯矩阵、证据与里程碑状态
