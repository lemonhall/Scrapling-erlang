# v1-fetchers-static

## Goal

建立静态 HTTP 抓取、session 复用、proxy rotation 与统一 response 契约，为 Spider 与 CLI 提供稳定抓取底座。

## PRD Trace

- REQ-0001-004
- REQ-0001-007

## Scope

### 做什么

- 提供 GET / POST / PUT / DELETE 抓取能力
- 提供 session 复用、cookies、headers、proxy 设置
- 提供 `ProxyRotator` 的 cyclic 与自定义策略入口
- 把抓取结果转换为统一 response / selector 结构

### 不做什么

- 不在本计划里实现浏览器自动化
- 不在本计划里实现 stealth 指纹
- 不在本计划里实现 Spider 调度逻辑

## Acceptance

1. `scrapling_fetcher` 和 `scrapling_fetcher_session` 支持四种常用 HTTP 方法
2. session 在多次请求间保持 cookies / headers / proxy 设定
3. `ProxyRotator` 至少支持 cyclic rotation 与函数回调式 rotation
4. response 能直接进入 parser / selector 层继续处理
5. 反作弊条款：测试必须跑本地 HTTP fixture server，不能只拿静态文件模拟网络层

## Files

- Create: `apps/scrapling/src/scrapling_response.erl`
- Create: `apps/scrapling/src/scrapling_fetcher.erl`
- Create: `apps/scrapling/src/scrapling_fetcher_session.erl`
- Create: `apps/scrapling/src/scrapling_proxy_rotator.erl`
- Create: `apps/scrapling/test/scrapling_fetcher_tests.erl`
- Create: `apps/scrapling/test/scrapling_session_tests.erl`
- Create: `apps/scrapling/test/scrapling_fetcher_e2e_tests.erl`

## Steps

1. 写失败测试（红）
   - `scrapling_fetcher_tests.erl` 覆盖方法、headers、response shape
   - `scrapling_session_tests.erl` 覆盖 cookies / proxy / rotation
2. 跑到红
   - Run: `rebar3 eunit -m scrapling_fetcher_tests`
   - Expected: 失败，原因是 fetcher 模块不存在
3. 实现最小静态抓取（绿）
   - 先落统一 response 契约
   - 再落基本请求方法
4. 跑到绿
   - Run: `rebar3 eunit -m scrapling_fetcher_tests`
   - Expected: PASS
5. 实现 session 与 proxy rotation（绿）
   - 引入 session state 与 rotator
6. 再跑到绿
   - Run: `rebar3 eunit -m scrapling_session_tests`
   - Expected: PASS
7. 必要重构（仍绿）
   - 抽取 adapter boundary，避免底层 client 泄漏进公开接口
8. E2E / 门禁
   - Run: `rebar3 eunit -m scrapling_fetcher_e2e_tests`
   - Expected: 本地 HTTP server 场景 PASS

## Risks

- HTTP 客户端选型会影响后续 TLS / header / HTTP2/3 行为
- session 状态如果没抽象好，浏览器 fetcher 与 spider 会重复造轮子
- proxy rotation 要定义清楚失败时如何切换与复用

