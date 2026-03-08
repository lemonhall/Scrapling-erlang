# v1 Index

## 愿景

- 愿景文档：`docs/prd/VISION.md`
- 主 PRD：`docs/prd/PRD-0001-scrapling-parity.md`
- 当前源项目基线：`E:\development\Scrapling`（2026-03-08 本机快照，版本 `0.4.1`）

## 方案选择

### 推荐方案：单主应用 + 清晰适配器边界

推荐从一个主 OTP 应用 `apps/scrapling/` 起步，内部按能力分模块，但对外只暴露稳定 facade。理由：

- 当前仓库为空，先把对外契约和追溯链建立好，比一上来拆多个 app 更稳
- parser / spider / CLI 都需要共享统一 response / selector / session 契约
- 浏览器与 HTTP 适配器会变化，先把边界做清楚，比过早切多 app 更利于收敛

### 备选方案：多应用 umbrella

适合后期把 `parser`、`browser adapter`、`cli` 拆成独立 app；但在 v1 启动阶段会增加脚手架成本，不作为首选。

### 明确不选：NIF-first 浏览器实现

浏览器与 stealth 能力优先经 Port / sidecar / CDP 走外部适配，不用 NIF 把复杂度提前锁死在仓内。

## 里程碑

| 里程碑 | 范围 | DoD | 验证命令 / 测试 | 状态 |
|---|---|---|---|---|
| M1 仓库基建 | 建立 `rebar3` 骨架、测试骨架、脚本骨架、文档矩阵 | `rebar.config`、`apps/scrapling/`、`scripts/erlang-env.ps1`、最小 eunit 全部到位；文档链路不缺口 | `rebar3 eunit -m scrapling_bootstrap_tests` | todo |
| M2 Parser / Adaptive | Selector、Selectors、导航、存储、relocate | 本地 fixture 上完成 CSS/XPath/regex/navigation/save/retrieve/relocate 行为 | `rebar3 eunit -m scrapling_selector_tests`；`rebar3 eunit -m scrapling_adaptive_tests` | todo |
| M3 Static Fetchers | HTTP Fetcher、Session、ProxyRotator、统一 Response | GET/POST/PUT/DELETE、session 复用、headers/cookies/proxy 全覆盖 | `rebar3 eunit -m scrapling_fetcher_tests` | todo |
| M4 Browser Fetchers | Dynamic / Stealth / browser sidecar | wait / page action / wait selector / blocked domains / stealth 配置可工作 | `rebar3 eunit -m scrapling_dynamic_fetcher_tests`；`rebar3 eunit -m scrapling_stealth_fetcher_tests` | todo |
| M5 Spider Runtime | Request、Scheduler、SessionManager、Engine、Spider、checkpoint、stream | crawl / pause / resume / stats / blocked retry / export 路径闭环 | `rebar3 eunit -m scrapling_spider_tests`；`rebar3 eunit -m scrapling_spider_e2e_tests` | todo |
| M6 CLI / AI / Docs | CLI、shell、MCP、文档对等、示例与证据 | 命令入口存在且能跑最小案例；PRD/计划/测试/证据闭环 | `rebar3 eunit -m scrapling_cli_tests`；`rebar3 eunit -m scrapling_mcp_tests`；`rebar3 eunit` | todo |

## 计划索引

| 文件 | Goal | 对应 Req IDs |
|---|---|---|
| `docs/plan/v1-repo-bootstrap.md` | 建立仓库基建、脚本骨架、最小测试与文档门禁 | REQ-0001-001, REQ-0001-012 |
| `docs/plan/v1-parser-adaptive.md` | 建立解析器、导航、adaptive 存储与 relocate 能力 | REQ-0001-002, REQ-0001-003 |
| `docs/plan/v1-fetchers-static.md` | 建立静态 HTTP 抓取、session、proxy rotation | REQ-0001-004, REQ-0001-007 |
| `docs/plan/v1-fetchers-browser.md` | 建立 dynamic / stealth 浏览器抓取能力 | REQ-0001-005, REQ-0001-006, REQ-0001-007 |
| `docs/plan/v1-spider-runtime.md` | 建立 Spider 运行时、checkpoint、streaming | REQ-0001-008, REQ-0001-009 |
| `docs/plan/v1-cli-ai-docs.md` | 建立 CLI / MCP / shell 与文档对等出口 | REQ-0001-010, REQ-0001-011, REQ-0001-012 |

## 追溯矩阵

| Req ID | v1 Plan | tests / commands | 证据 | 状态 |
|---|---|---|---|---|
| REQ-0001-001 | `v1-repo-bootstrap` | 文档追溯检查 + bootstrap smoke | `docs/plan/v1-index.md` | todo |
| REQ-0001-002 | `v1-parser-adaptive` | `rebar3 eunit -m scrapling_selector_tests` | `_build/test/logs/...` | todo |
| REQ-0001-003 | `v1-parser-adaptive` | `rebar3 eunit -m scrapling_adaptive_tests` | `_build/test/logs/...` | todo |
| REQ-0001-004 | `v1-fetchers-static` | `rebar3 eunit -m scrapling_fetcher_tests` | `_build/test/logs/...` | todo |
| REQ-0001-005 | `v1-fetchers-browser` | `rebar3 eunit -m scrapling_dynamic_fetcher_tests` | `_build/test/logs/...` | todo |
| REQ-0001-006 | `v1-fetchers-browser` | `rebar3 eunit -m scrapling_stealth_fetcher_tests` | `_build/test/logs/...` | todo |
| REQ-0001-007 | `v1-fetchers-static` / `v1-fetchers-browser` | `rebar3 eunit -m scrapling_session_tests` | `_build/test/logs/...` | todo |
| REQ-0001-008 | `v1-spider-runtime` | `rebar3 eunit -m scrapling_spider_tests` | `_build/test/logs/...` | todo |
| REQ-0001-009 | `v1-spider-runtime` | `rebar3 eunit -m scrapling_spider_e2e_tests` | checkpoint 与日志产物 | todo |
| REQ-0001-010 | `v1-cli-ai-docs` | `rebar3 eunit -m scrapling_cli_tests` | `_build/test/logs/...` | todo |
| REQ-0001-011 | `v1-cli-ai-docs` | `rebar3 eunit -m scrapling_mcp_tests` | `_build/test/logs/...` | todo |
| REQ-0001-012 | `v1-repo-bootstrap` / `v1-cli-ai-docs` | `rebar3 eunit` | 全量测试日志 | todo |

## ECN 索引

- 当前为空
- 任何设计变更进入：`docs/ecn/ECN-NNNN-<topic>.md`

## 差异列表

- 当前仓库尚未初始化为 `rebar3` 项目，M1 尚未开始
- 当前仓库尚未建立 git 仓库；后续执行到 Ship 阶段前需补齐
- 浏览器 / stealth 能力在 Erlang 中需要 adapter 设计，暂未冻结具体底层实现
- 源项目文档量大于本仓当前文档量，后续必须把使用文档和 API 文档补齐，不能只交代码

