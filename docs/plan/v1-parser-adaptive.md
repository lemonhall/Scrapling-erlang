# v1-parser-adaptive

## Goal

建立 `Selector / Selectors` 解析核心，以及 adaptive 存储与 `relocate` 行为，让 Erlang 侧具备源项目 parser 的核心价值。

## Status

- 状态：doing
- 当前完成：最小 `from_html/1`、`xpath/2`、`css/2`、`text/1`、`attribute/2`、`tag/1`、`children/1`、`re/2`、`re_first/2`、`get/1`、`getall/1` 与 `Selectors` 集合包装已落地
- 当前证据：`rebar3 eunit -m scrapling_selector_tests`、`rebar3 eunit`

## PRD Trace

- REQ-0001-002
- REQ-0001-003

## Scope

### 做什么

- 解析 HTML 为 selector 树
- 支持 CSS、XPath、文本、正则、filter、json 抽取
- 支持 parent / children / siblings / ancestor / next / previous 导航
- 支持 auto-save / retrieve / relocate 所需的存储与匹配能力

### 不做什么

- 不在本计划里实现 HTTP 请求
- 不在本计划里实现浏览器驱动
- 不在本计划里把文档站点全部写完

## Acceptance

1. 本地 fixture HTML 上支持 CSS 与 XPath 查询并返回稳定结果
2. `get/0 or 1`、`getall`、文本、属性、HTML、JSON 抽取行为可验证
3. `parent`、`children`、`siblings`、`find_ancestor`、`next`、`previous` 行为可验证
4. `save` / `retrieve` / `relocate` 在 DOM 改版 fixture 上可命中目标
5. 反作弊条款：测试必须至少使用两份不同 HTML fixture；不得靠硬编码返回预期值伪造 `relocate`

## Files

- Create: `apps/scrapling/src/scrapling_selector.erl`
- Create: `apps/scrapling/src/scrapling_selectors.erl`
- Create: `apps/scrapling/src/scrapling_storage.erl`
- Create: `apps/scrapling/src/scrapling_adaptive.erl`
- Create: `apps/scrapling/test/scrapling_selector_tests.erl`
- Create: `apps/scrapling/test/scrapling_adaptive_tests.erl`
- Create: `apps/scrapling/test/fixtures/parser_base.html`
- Create: `apps/scrapling/test/fixtures/parser_changed.html`

## Steps

1. 写失败测试（红）
   - 先写 `scrapling_selector_tests.erl` 覆盖 CSS/XPath/text/navigation
   - 再写 `scrapling_adaptive_tests.erl` 覆盖 save/retrieve/relocate
2. 跑到红
   - Run: `rebar3 eunit -m scrapling_selector_tests`
   - Expected: 失败，原因是 selector 模块不存在或接口缺失
3. 实现最小可用 parser（绿）
   - 先实现 fixture 驱动的解析与选择
   - 再补导航与类型转换
4. 跑到绿
   - Run: `rebar3 eunit -m scrapling_selector_tests`
   - Expected: PASS
5. 实现 adaptive（绿）
   - 引入存储、元素特征、匹配与 relocate
6. 再跑到绿
   - Run: `rebar3 eunit -m scrapling_adaptive_tests`
   - Expected: PASS
7. 必要重构（仍绿）
   - 抽取公共 selector record / map 契约
8. E2E / 门禁
   - Run: `rebar3 eunit -m scrapling_selector_tests -m scrapling_adaptive_tests`
   - Expected: PASS

## Risks

- CSS / XPath 支持的库选型会影响后续 API 语义稳定性
- adaptive 匹配如果没有稳定的数据契约，后面 fetcher / spider 接口会返工
- JSON / 文本处理要提早统一编码策略
