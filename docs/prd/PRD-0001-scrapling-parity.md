# PRD-0001: Scrapling Erlang Parity

## 0) 元信息

- Topic：Scrapling Erlang 对等实现
- Owner：柠檬叔 / Codex 协作执行
- Status：draft
- Version：v1
- Last updated：2026-03-08
- Links：
  - 愿景：`docs/prd/VISION.md`
  - 计划入口：`docs/plan/v1-index.md`

## 1) 背景与问题（Problem Statement）

当前本机已经有一个成熟的 Python 项目 `E:\development\Scrapling`，它提供了完整的 Web Scraping 能力面，包括：

- HTML 解析与智能元素定位
- 静态 HTTP 抓取与会话管理
- 动态浏览器抓取与 stealth 抓取
- Spider 框架、checkpoint、streaming、stats
- CLI、交互式 shell、MCP / AI 集成

但本地 `E:\development\Scrapling-erlang` 目前仍是空目录。这意味着：

- Erlang / OTP 生态暂无本仓内的对等能力承载
- 后续任何“复刻”都容易在没有追溯和约束的情况下跑偏
- 如果不先冻结目标能力面，后面会出现“以为做完了，其实只做了一个最小子集”的返工问题

### 已确认事实（来自 2026-03-08 本地扫描）

- 源项目版本：`scrapling/__init__.py` 标记为 `0.4.1`
- 源项目公开能力面包括：
  - 解析：`scrapling/parser.py`
  - 抓取：`scrapling/fetchers/*.py`
  - Spider：`scrapling/spiders/*.py`
  - CLI：`scrapling/cli.py`
  - AI/MCP：`docs/ai/`、`docs/api-reference/mcp-server.md`
- 源项目文档按 Diátaxis 组织，含 parsing / fetching / spiders / cli / ai / api-reference / tutorials
- 源项目测试文件共 34 个，覆盖 parser / fetchers / spiders / cli / core / ai 等区域

## 2) 目标（Goals）

- G1：为源项目每个公开能力建立稳定的 `Req ID` 与追溯链
- G2：在 Erlang/OTP 中提供与源项目对等的解析、抓取、Spider、CLI、AI/MCP 能力
- G3：把“像素级复刻”定义为**行为对等 + 文档对等 + 测试可证**，而不是“名字像”
- G4：在整个执行过程中，禁止静默删减需求，所有偏差都必须进入差异清单或 ECN

## 3) 非目标（Non-goals）

- NG1：不承诺 Python 代码逐行翻译；本项目是 **Erlang 化实现**，不是 Python 解释器
- NG2：不在本轮偷偷扩展到其他语言 sibling；如需扩范围，对本 PRD 走 ECN
- NG3：不把“暂时返回占位值”的假实现视为能力完成

## 4) 术语与口径（Glossary / Contracts）

- **Source Snapshot**：指 2026-03-08 本机目录 `E:\development\Scrapling` 的代码与文档状态
- **Parity**：指能力、语义、验证与文档入口可一一对应，不要求语法字面复制
- **Selector**：对 HTML / DOM 节点与节点集合的统一抽象
- **Fetcher**：对静态 HTTP 抓取、动态浏览器抓取、stealth 抓取的统一抽象
- **Spider Runtime**：请求、调度、session、stats、checkpoint、流式导出的总称
- **Req ID**：格式为 `REQ-0001-NNN`，对应本 PRD 的需求编号

## 5) 用户画像与关键场景（Personas & Scenarios）

- S1：作为 Erlang 开发者，我需要像用 Scrapling 一样解析 HTML 并在页面结构变动后继续定位目标元素
- S2：作为采集工程师，我需要在同一套 API 下使用静态 HTTP、动态浏览器和 stealth 模式抓取网站
- S3：作为长期运行服务的维护者，我需要 Spider 能暂停、恢复、输出 stats，并在异常时给出可诊断证据
- S4：作为工具链集成者，我需要 CLI 与 MCP 接口，让抓取能力被脚本、终端与 AI 代理复用

## 6) 源项目能力盘点（冻结为本 PRD 的设计输入）

### 6.1 公开模块面

| 源区域 | 本地路径 | 观察结果 |
|---|---|---|
| 版本入口 | `scrapling/__init__.py` | 暴露 `Fetcher` / `Selector` / `AsyncFetcher` / `StealthyFetcher` / `DynamicFetcher` |
| 解析器 | `scrapling/parser.py` | `Selector` / `Selectors`，支持 CSS/XPath/导航/存储/relocate/json |
| 抓取器 | `scrapling/fetchers/` | 静态 `Fetcher`、动态 `DynamicFetcher`、stealth `StealthyFetcher`、session 类型 |
| Spider | `scrapling/spiders/` | `Request` / `Scheduler` / `SessionManager` / `CrawlerEngine` / `Spider` / `CrawlResult` |
| CLI | `scrapling/cli.py` | `install` / `mcp` / `shell` / `extract` / `get` / `post` / `put` / `delete` / `fetch` / `stealthy_fetch` |
| 文档 | `docs/` | 覆盖 fetching / parsing / spiders / cli / ai / api-reference / tutorials |

### 6.2 测试面

| 测试组 | 数量 |
|---|---:|
| `tests/parser/` | 4 |
| `tests/fetchers/` | 18 |
| `tests/spiders/` | 7 |
| `tests/cli/` | 2 |
| `tests/core/` | 2 |
| `tests/ai/` | 1 |

## 7) 需求清单（Requirements with Req IDs）

| Req ID | 需求描述 | 验收口径（可二元判定） | 验证方式（命令/测试/步骤） | 优先级 | 依赖/风险 |
|---|---|---|---|---|---|
| REQ-0001-001 | 冻结并维护源项目能力映射表 | 源项目每个公开能力都能映射到本仓模块、计划、测试入口，且没有“未登记能力” | 检查 `docs/prd/PRD-0001-scrapling-parity.md` 与 `docs/plan/v1-index.md` 追溯矩阵 | P0 | 若映射缺失，后续会静默打折 |
| REQ-0001-002 | 提供 Selector / Selectors 解析能力 | 能完成 CSS、XPath、文本、正则、关系导航、属性/HTML/JSON 抽取 | `rebar3 eunit -m scrapling_selector_tests` | P0 | HTML/CSS 解析库选型 |
| REQ-0001-003 | 提供 adaptive element tracking | 能保存元素指纹并在 DOM 改版后 relocate 命中目标 | `rebar3 eunit -m scrapling_adaptive_tests` | P0 | 存储格式、相似度算法 |
| REQ-0001-004 | 提供静态 HTTP Fetcher 与 Session | 支持 GET/POST/PUT/DELETE、headers/cookies/proxy/session 复用，统一返回 response/selectors | `rebar3 eunit -m scrapling_fetcher_tests` | P0 | HTTP 客户端适配 |
| REQ-0001-005 | 提供动态浏览器 Fetcher | 支持浏览器驱动抓取、wait 策略、page action、selector wait、domain blocking | `rebar3 eunit -m scrapling_dynamic_fetcher_tests` | P0 | 浏览器 sidecar / CDP 集成 |
| REQ-0001-006 | 提供 stealth 抓取与指纹能力 | 支持 stealth 模式、指纹与 referer 策略、反拦截流程的可配置控制 | `rebar3 eunit -m scrapling_stealth_fetcher_tests` | P0 | 浏览器伪装边界 |
| REQ-0001-007 | 提供 async / multi-session / proxy rotation | 支持并发 session 与代理轮换策略，且不会把具体适配器类型暴露到公开接口 | `rebar3 eunit -m scrapling_session_tests` | P0 | OTP 并发模型与外部适配器 |
| REQ-0001-008 | 提供 Spider 运行时 | 包括 Request、Scheduler、SessionManager、CrawlerEngine、Spider、CrawlResult、CrawlStats | `rebar3 eunit -m scrapling_spider_tests` | P0 | 调度、回调与导出语义 |
| REQ-0001-009 | 支持 pause / resume / checkpoint / stream / blocked retry | Spider 在中断后可恢复，并支持流式产出与 blocked request 处理 | `rebar3 eunit -m scrapling_spider_e2e_tests` | P0 | checkpoint 一致性 |
| REQ-0001-010 | 提供 CLI 与交互式工作流入口 | 提供与源项目能力对应的命令入口：`install` / `extract` / `shell` / `mcp` | `rebar3 eunit -m scrapling_cli_tests` | P1 | escript / shell UX |
| REQ-0001-011 | 提供 AI / MCP 集成 | 能通过 MCP 风格接口暴露定向提取能力，减少上下文体积 | `rebar3 eunit -m scrapling_mcp_tests` | P1 | 协议设计与兼容 |
| REQ-0001-012 | 建立持续可验收的质量门禁 | 对每一项能力给出测试入口、E2E 路径与证据位置，禁止“手测算完成” | `rebar3 eunit` + 文档追溯检查 | P0 | 仓库基建尚未存在 |

## 8) 约束与不接受（Constraints）

- 不接受“只做 parser，不做 fetchers / spiders / CLI”这类范围缩减，除非进入 ECN 或差异列表
- 不接受把具体第三方适配器的内部结构泄漏成公开 API
- 不接受只有 happy path 的测试；至少要覆盖正常、异常、边界三类场景
- 不接受“文档说支持，但代码没有，测试也没有”的伪完成功能
- 不接受在 Windows 11 + `pwsh.exe` 下无法稳定复现的开发流程

## 9) 推荐实现方向（当前设计输入，不是最终代码）

- 解析层：Erlang 原生模块 + 清晰的 selector 数据契约
- HTTP 抓取层：独立 adapter boundary，允许后续替换底层实现
- 浏览器抓取层：Port / sidecar 优先，不做 NIF-first
- Spider 层：OTP 监督树、调度进程、checkpoint 持久化
- CLI / MCP：以 Erlang 主程序为入口，对外暴露稳定命令和协议

## 10) 可观测性

- 所有 milestone 的验证命令必须能产生日志或可定位产物
- fixture、checkpoint、导出结果需要有固定路径
- browser / network / blocked retry 场景需要留失败诊断信息

## 11) 追溯矩阵（种子版）

| Req ID | v1 计划条目 | tests/commands | 证据（log/artifact） | 关键代码路径 |
|---|---|---|---|---|
| REQ-0001-001 | `docs/plan/v1-repo-bootstrap.md` | 文档追溯检查 | `docs/plan/v1-index.md` | `docs/prd/` / `docs/plan/` |
| REQ-0001-002 | `docs/plan/v1-parser-adaptive.md` | `rebar3 eunit -m scrapling_selector_tests` | `_build/test/logs/...` | `apps/scrapling/src/scrapling_selector*.erl` |
| REQ-0001-003 | `docs/plan/v1-parser-adaptive.md` | `rebar3 eunit -m scrapling_adaptive_tests` | `_build/test/logs/...` | `apps/scrapling/src/scrapling_storage*.erl` |
| REQ-0001-004 | `docs/plan/v1-fetchers-static.md` | `rebar3 eunit -m scrapling_fetcher_tests` | `_build/test/logs/...` | `apps/scrapling/src/scrapling_fetcher*.erl` |
| REQ-0001-005 | `docs/plan/v1-fetchers-browser.md` | `rebar3 eunit -m scrapling_dynamic_fetcher_tests` | `_build/test/logs/...` | `apps/scrapling/src/scrapling_dynamic*.erl` |
| REQ-0001-006 | `docs/plan/v1-fetchers-browser.md` | `rebar3 eunit -m scrapling_stealth_fetcher_tests` | `_build/test/logs/...` | `apps/scrapling/src/scrapling_stealth*.erl` |
| REQ-0001-007 | `docs/plan/v1-fetchers-static.md` / `docs/plan/v1-fetchers-browser.md` | `rebar3 eunit -m scrapling_session_tests` | `_build/test/logs/...` | `apps/scrapling/src/scrapling_session*.erl` |
| REQ-0001-008 | `docs/plan/v1-spider-runtime.md` | `rebar3 eunit -m scrapling_spider_tests` | `_build/test/logs/...` | `apps/scrapling/src/scrapling_spider*.erl` |
| REQ-0001-009 | `docs/plan/v1-spider-runtime.md` | `rebar3 eunit -m scrapling_spider_e2e_tests` | `_build/test/logs/...` / checkpoint fixture | `apps/scrapling/src/scrapling_checkpoint*.erl` |
| REQ-0001-010 | `docs/plan/v1-cli-ai-docs.md` | `rebar3 eunit -m scrapling_cli_tests` | `_build/test/logs/...` | `apps/scrapling/src/scrapling_cli*.erl` |
| REQ-0001-011 | `docs/plan/v1-cli-ai-docs.md` | `rebar3 eunit -m scrapling_mcp_tests` | `_build/test/logs/...` | `apps/scrapling/src/scrapling_mcp*.erl` |
| REQ-0001-012 | `docs/plan/v1-index.md` | `rebar3 eunit` | `_build/test/logs/...` | `apps/scrapling/test/` / `scripts/` |
