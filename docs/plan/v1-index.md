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
| M1 仓库基建 | 建立 `rebar3` 骨架、测试骨架、脚本骨架、文档矩阵 | `rebar.config`、`apps/scrapling/`、`scripts/erlang-env.ps1`、最小 eunit 全部到位；文档链路不缺口 | `rebar3 eunit -m scrapling_bootstrap_tests` | done |
| M2 Parser / Adaptive | Selector、Selectors、导航、存储、relocate | 本地 fixture 上完成 CSS/XPath/regex/navigation/save/retrieve/relocate 行为 | `rebar3 eunit -m scrapling_selector_tests`；`rebar3 eunit -m scrapling_adaptive_tests` | doing |
| M3 Static Fetchers | HTTP Fetcher、Session、ProxyRotator、统一 Response | GET/POST/PUT/DELETE、session 复用、headers/cookies/proxy 全覆盖 | `rebar3 eunit -m scrapling_fetcher_tests`；`rebar3 eunit -m scrapling_session_tests`；`rebar3 eunit -m scrapling_fetcher_e2e_tests` | done |
| M4 Browser Fetchers | Dynamic / Stealth / browser sidecar | wait / wait selector / `wait_selector_state` / `blocked_domains` 目标域拦截 / stealth 配置入口可工作；`page_action` 与真实 CDP 接管待继续补齐 | `rebar3 eunit -m scrapling_browser_contract_tests`；`rebar3 eunit -m scrapling_dynamic_fetcher_tests`；`rebar3 eunit -m scrapling_stealth_fetcher_tests` | doing |
| M5 Spider Runtime | Request、Scheduler、SessionManager、Engine、Spider、checkpoint、stream | 最小串行 crawl 已就位：`Request` / `Scheduler` / `SessionManager` / `Engine` / `Spider` 已可跑；后续补齐 pause / resume / checkpoint / stream / blocked retry / export | `rebar3 eunit -m scrapling_request_tests`；`rebar3 eunit -m scrapling_scheduler_tests`；`rebar3 eunit -m scrapling_session_manager_tests`；`rebar3 eunit -m scrapling_spider_tests`；`rebar3 eunit -m scrapling_spider_e2e_tests` | doing |
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
| REQ-0001-001 | `v1-repo-bootstrap` | 文档追溯检查 + bootstrap smoke | `docs/plan/v1-index.md`、`docs/prd/PRD-0001-scrapling-parity.md` | done |
| REQ-0001-002 | `v1-parser-adaptive` | `rebar3 eunit -m scrapling_selector_tests`；`rebar3 eunit -m scrapling_selectors_tests` | 当前证据：已补齐 `parent/siblings/next/previous/find_ancestor`，并对齐多 class CSS 选择语义，selector / selectors 测试已通过 | doing |
| REQ-0001-003 | `v1-parser-adaptive` | `rebar3 eunit -m scrapling_adaptive_tests` | 当前证据：手工 `save/retrieve/relocate` 与 `XPath adaptive/auto_save` slice 已通过 | doing |
| REQ-0001-004 | `v1-fetchers-static` | `rebar3 eunit -m scrapling_fetcher_tests`；`rebar3 eunit -m scrapling_fetcher_e2e_tests` | 当前证据：静态 GET/POST/PUT/DELETE、统一 Response、本地 HTTP fixture server 已通过 | done |
| REQ-0001-005 | `v1-fetchers-browser` | `rebar3 eunit -m scrapling_browser_contract_tests`；`rebar3 eunit -m scrapling_dynamic_fetcher_tests`；`rebar3 eunit -m scrapling_dynamic_session_tests` | 当前证据：Port sidecar 契约、最小 dynamic fetcher、dynamic session 默认参数复用、本地 sidecar E2E 已通过；`cdp_url` 非法/未支持错误、`wait_selector_state` 四态语义与 `blocked_domains` exact/subdomain 目标域拦截已固化 | doing |
| REQ-0001-006 | `v1-fetchers-browser` | `rebar3 eunit -m scrapling_stealth_fetcher_tests`；`rebar3 eunit -m scrapling_stealth_session_tests` | 当前证据：`StealthFetcher`/`StealthSession` 最小包装层、stealth meta 契约、浏览器错误传播与 session 错误隔离已通过；真实 stealth 指纹待继续扩充 | doing |
| REQ-0001-007 | `v1-fetchers-static` / `v1-fetchers-browser` | `rebar3 eunit -m scrapling_session_tests` | 当前证据：静态 session 的 cookies / headers / proxy rotation 已通过；浏览器 session 坏请求不会打崩进程，后续请求仍可继续 | doing |
| REQ-0001-008 | `v1-spider-runtime` | `rebar3 eunit -m scrapling_request_tests`；`rebar3 eunit -m scrapling_scheduler_tests`；`rebar3 eunit -m scrapling_session_manager_tests`；`rebar3 eunit -m scrapling_spider_tests` | 当前证据：`scrapling_request`、`scrapling_scheduler`、`scrapling_session_manager`、`scrapling_crawler_engine`、`scrapling_spider` 的最小串行 crawl 已通过 | doing |
| REQ-0001-009 | `v1-spider-runtime` | `rebar3 eunit -m scrapling_spider_e2e_tests` | checkpoint 与日志产物 | todo |
| REQ-0001-010 | `v1-cli-ai-docs` | `rebar3 eunit -m scrapling_cli_tests` | `_build/test/logs/...` | todo |
| REQ-0001-011 | `v1-cli-ai-docs` | `rebar3 eunit -m scrapling_mcp_tests` | `_build/test/logs/...` | todo |
| REQ-0001-012 | `v1-repo-bootstrap` / `v1-cli-ai-docs` | `rebar3 eunit` | 当前证据：当前全量 `eunit` 共 `59` 条测试通过；最终全仓门禁待继续扩充 | doing |

## ECN 索引

- 当前为空
- 任何设计变更进入：`docs/ecn/ECN-NNNN-<topic>.md`

## 差异列表

- Git 仓库已建立，并约定直接在 `main` 上按 slice `commit + push`
- 浏览器 / stealth 能力在 Erlang 中需要 adapter 设计，暂未冻结具体底层实现
- 源项目文档量大于本仓当前文档量，后续必须把使用文档和 API 文档补齐，不能只交代码
