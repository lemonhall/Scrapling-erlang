# v1-fetchers-browser

## Goal

建立 dynamic / stealth 浏览器抓取能力，并以 sidecar / Port 边界把浏览器自动化与 Erlang 主体解耦。

## PRD Trace

- REQ-0001-005
- REQ-0001-006
- REQ-0001-007

## Scope

### 做什么

- 提供 `DynamicFetcher` 对等能力：浏览器加载、wait、selector wait、page action、domain blocking
- 提供 `StealthFetcher` 对等能力：stealth 配置、referer / 指纹策略、可配置的阻断处理
- 统一 session / response 契约与 parser 对接

### 不做什么

- 不在本计划里实现完整 Spider runtime
- 不在本计划里实现所有 AI / CLI 功能
- 不在本计划里承诺零外部依赖的浏览器实现

## Acceptance

1. 能通过 sidecar / Port 调起浏览器抓取并返回统一 response
2. 支持 headless、wait、network idle、wait selector、page action 等关键参数
3. 支持 blocked domains 与 per-request proxy
4. 支持 stealth 相关配置入口与可诊断错误输出
5. 反作弊条款：至少一条测试必须真实调用 sidecar 契约，而不是只 mock Erlang 函数返回值

## Files

- Create: `apps/scrapling/src/scrapling_browser_port.erl`
- Create: `apps/scrapling/src/scrapling_dynamic_fetcher.erl`
- Create: `apps/scrapling/src/scrapling_dynamic_session.erl`
- Create: `apps/scrapling/src/scrapling_stealth_fetcher.erl`
- Create: `apps/scrapling/src/scrapling_stealth_session.erl`
- Create: `apps/scrapling/test/scrapling_dynamic_fetcher_tests.erl`
- Create: `apps/scrapling/test/scrapling_stealth_fetcher_tests.erl`
- Create: `apps/scrapling/test/scrapling_browser_contract_tests.erl`
- Create: `apps/scrapling/priv/browser/`（sidecar 相关脚本与协议定义）

## Steps

1. 写失败测试（红）
   - 先写 sidecar contract tests
   - 再写 dynamic 与 stealth 的最小行为测试
2. 跑到红
   - Run: `rebar3 eunit -m scrapling_browser_contract_tests`
   - Expected: 失败，原因是 sidecar 协议与模块不存在
3. 实现浏览器契约（绿）
   - 定义 Port 消息格式、超时、错误结构、诊断输出
4. 跑到绿
   - Run: `rebar3 eunit -m scrapling_browser_contract_tests`
   - Expected: PASS
5. 实现 dynamic / stealth fetchers（绿）
   - 先落 dynamic，再落 stealth
6. 再跑到绿
   - Run: `rebar3 eunit -m scrapling_dynamic_fetcher_tests`
   - Expected: PASS
   - Run: `rebar3 eunit -m scrapling_stealth_fetcher_tests`
   - Expected: PASS
7. 必要重构（仍绿）
   - 清理 adapter-specific 数据结构，统一 session / response 契约
8. E2E / 门禁
   - Run: `rebar3 eunit -m scrapling_browser_contract_tests -m scrapling_dynamic_fetcher_tests -m scrapling_stealth_fetcher_tests`
   - Expected: PASS

## Risks

- 浏览器 sidecar 的跨平台与代理能力是本计划的最大不确定项
- stealth 的真实效果需要留出诊断与替换空间，不能把某个实现细节写死为公开 API
- 真实网页 E2E 需要代理与外网环境，必须保持本地可关闭、可替换

## Implementation Status

- 已完成：`scrapling_browser_port` Port sidecar 契约与 Python sidecar 最小实现
- 已完成：`scrapling_dynamic_fetcher` 通过 sidecar 获取页面并转换为统一 `scrapling_response`
- 已完成：`scrapling_dynamic_session` 支持默认参数复用与逐请求覆盖
- 已完成：`scrapling_stealth_fetcher` 最小包装层，先把 stealth 参数面与统一 response 契约打通
- 已完成：本地 HTTP fixture + 真实 sidecar 进程的 contract test
- 待完成：`scrapling_stealth_session`
- 待完成：更完整的浏览器参数语义（`page_action`、真实资源拦截、stealth 指纹）

## Evidence

- `rebar3 eunit -m scrapling_browser_contract_tests`
- `rebar3 eunit -m scrapling_dynamic_fetcher_tests`
- `rebar3 eunit -m scrapling_dynamic_session_tests`
- `rebar3 eunit -m scrapling_stealth_fetcher_tests`
- `rebar3 eunit`
