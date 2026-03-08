# v1-spider-runtime

## Goal

建立 Spider 运行时，包括 request / scheduler / session manager / engine / checkpoint / stats / streaming，让 Erlang 侧具备长期运行与可恢复 crawl 能力。

## PRD Trace

- REQ-0001-008
- REQ-0001-009

## Scope

### 做什么

- 建立 `Request`、`Scheduler`、`SessionManager`、`CrawlerEngine`、`Spider`、`CrawlResult`、`CrawlStats`
- 支持 pause / resume / checkpoint
- 支持 stream 模式与 blocked request retry
- 支持结果导出与运行期 stats

### 不做什么

- 不在本计划里补完整文档站点
- 不在本计划里引入分布式调度
- 不在本计划里把所有浏览器细节再次实现一遍

## Acceptance

1. 一个最小 Spider 能从 `start_urls` 进入 `parse` 并产出 item
2. 支持多 session 配置并按 session id 路由请求
3. `pause` 后能生成 checkpoint，重启后可恢复 crawl
4. `stream` 模式能逐项吐出 item，并可同时读取 stats
5. 反作弊条款：必须有至少一个 checkpoint 恢复的 E2E 场景，不能只测 scheduler 内部函数

## Files

- Create: `apps/scrapling/src/scrapling_request.erl`
- Create: `apps/scrapling/src/scrapling_scheduler.erl`
- Create: `apps/scrapling/src/scrapling_session_manager.erl`
- Create: `apps/scrapling/src/scrapling_checkpoint.erl`
- Create: `apps/scrapling/src/scrapling_crawl_stats.erl`
- Create: `apps/scrapling/src/scrapling_crawl_result.erl`
- Create: `apps/scrapling/src/scrapling_crawler_engine.erl`
- Create: `apps/scrapling/src/scrapling_spider.erl`
- Create: `apps/scrapling/test/scrapling_request_tests.erl`
- Create: `apps/scrapling/test/scrapling_scheduler_tests.erl`
- Create: `apps/scrapling/test/scrapling_session_manager_tests.erl`
- Create: `apps/scrapling/test/scrapling_test_spider_minimal.erl`
- Create: `apps/scrapling/test/scrapling_checkpoint_tests.erl`
- Create: `apps/scrapling/test/scrapling_spider_tests.erl`
- Create: `apps/scrapling/test/scrapling_spider_e2e_tests.erl`

## Steps

1. 写失败测试（红）
   - `scrapling_spider_tests.erl` 覆盖最小 crawl、request 复制、scheduler enqueue/dequeue、stats
   - `scrapling_spider_e2e_tests.erl` 覆盖 pause/resume/checkpoint/stream
2. 跑到红
   - Run: `rebar3 eunit -m scrapling_spider_tests`
   - Expected: 失败，原因是 Spider 运行时模块不存在
3. 实现最小 Spider 运行时（绿）
   - 先落 request / scheduler / engine 最小闭环
4. 跑到绿
   - Run: `rebar3 eunit -m scrapling_spider_tests`
   - Expected: PASS
5. 实现 checkpoint / stream / blocked retry（绿）
   - 引入 checkpoint 持久化与恢复逻辑
6. 再跑到绿
   - Run: `rebar3 eunit -m scrapling_spider_e2e_tests`
   - Expected: PASS
7. 必要重构（仍绿）
   - 抽取 hook、stats、session 配置口径
8. E2E / 门禁
   - Run: `rebar3 eunit -m scrapling_spider_tests -m scrapling_spider_e2e_tests`
   - Expected: PASS

## Risks

- Spider callback 与 OTP 进程模型之间的接口语义要尽早固定
- checkpoint 的格式一旦泄漏到公开 API，后续很难调整
- blocked retry 需要和 fetcher 错误结构统一，否则诊断会混乱

## Implementation Status

- 已完成：`scrapling_request` 值对象首轮切片，支持 `url/sid/callback/priority/dont_filter/meta/session_opts` 访问
- 已完成：`scrapling_request:copy/1`、`domain/1` 与最小 `fingerprint/1`，为后续 scheduler 去重与 session 路由铺路
- 已完成：`scrapling_request_tests` 固化默认字段、复制语义与指纹稳定性
- 已完成：`scrapling_scheduler` 首轮切片，支持优先级出队、指纹去重、`dont_filter`、`snapshot/restore`
- 已完成：`scrapling_scheduler_tests` 固化空队列、优先级、去重与快照恢复语义
- 已完成：`scrapling_session_manager` 首轮切片，支持默认 session、按 `sid` 路由、自定义 fetch adapter、现有 static/dynamic/stealth session pid 路由，以及请求 `meta` 合并回 response
- 已完成：`scrapling_session_manager_tests` 固化默认 session、重复 ID 错误、路由与 response `meta/request` 回填语义
- 已完成：`scrapling_crawl_stats` / `scrapling_crawl_result` / `scrapling_crawler_engine` / `scrapling_spider` 最小串行 crawl 闭环
- 已完成：`scrapling_spider_tests` 固化 `start_urls -> parse -> item -> follow-up request` 与 `allowed_domains` 过滤语义
- 已完成：`scrapling_checkpoint` 首轮切片，支持 checkpoint save/load/cleanup roundtrip
- 已完成：`scrapling_checkpoint_tests` 固化请求与 seen 的持久化回环
- 已完成：resume 路径已接入 `scrapling_spider:start/2`，可从已有 checkpoint 恢复 pending requests 并在成功完成后清理 checkpoint 文件
- 已完成：`scrapling_spider_e2e_tests` 首轮覆盖 checkpoint restore -> crawl completion 闭环
- 已完成：程序化 `pause_after_requests` 触发已接入 engine，可在 crawl 中途保存 pending requests 到 checkpoint 并返回未完成结果
- 已完成：`scrapling_spider_e2e_tests` 已覆盖 pause -> checkpoint 与 checkpoint -> resume 两条 E2E 主路径
- 已完成：`scrapling_spider:stream/2`、`next/2`、`stats/1` 已接入，支持逐项吐出 item，并在流式消费期间读取运行中 stats
- 已完成：`scrapling_crawler_engine` 已抽出 `on_item` / `on_stats` hook，供流式消费复用同一套 crawl 闭环
- 已完成：blocked response 检测、`retry_count` 累加、`dont_filter` 强制、priority 降级、proxy 清理与 `retry_blocked_request/2` hook 已接入 engine 主循环
- 已完成：`scrapling_spider:run/2`、`pause/1`、`await/2` 已接入统一 controller，支持外部发起 graceful pause
- 已完成：pause 语义已对齐源仓：有 checkpoint 时返回未完成结果并保留 checkpoint；无 checkpoint 时优雅停止且结果仍标记为 completed
- 已完成：`scrapling_spider_e2e_tests` 已覆盖 stream item-by-item + live stats、blocked retry recover/exhaust、external pause signal checkpoint/graceful-stop 主路径
- 当前结论：REQ-0001-009 验收项已完成，后续增强回到更高阶 runtime parity 收敛

## Evidence

- `rebar3 eunit -m scrapling_request_tests`
- `rebar3 eunit -m scrapling_scheduler_tests`
- `rebar3 eunit -m scrapling_session_manager_tests`
- `rebar3 eunit -m scrapling_spider_tests`
- `rebar3 eunit -m scrapling_checkpoint_tests`
- `rebar3 eunit -m scrapling_spider_e2e_tests`
- `rebar3 eunit`
