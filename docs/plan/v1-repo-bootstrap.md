# v1-repo-bootstrap

## Goal

把空目录启动为可执行的 Erlang/OTP 项目骨架，并把文档矩阵、脚本骨架、最小测试门禁一次性建立起来，为后续 parity 工作提供稳定底座。

## PRD Trace

- REQ-0001-001
- REQ-0001-012

## Scope

### 做什么

- 创建 `rebar3` 项目骨架与 `apps/scrapling/` 主应用
- 创建最小 facade、版本信息、最小 smoke test
- 创建 `scripts/erlang-env.ps1` 与基础 `.gitignore`
- 建立 `apps/scrapling/test/fixtures/` 与文档校验入口

### 不做什么

- 不在本计划里实现 parser / fetcher / spider 的完整行为
- 不在本计划里引入浏览器 sidecar
- 不在本计划里宣称任何 parity 功能已完成

## Acceptance

1. `rebar.config`、`apps/scrapling/src/scrapling.app.src`、`apps/scrapling/src/scrapling.erl` 存在
2. `apps/scrapling/test/scrapling_bootstrap_tests.erl` 能通过
3. `scripts/erlang-env.ps1` 能设置 Erlang / rebar3 / proxy 会话变量
4. `rebar3 eunit -m scrapling_bootstrap_tests` 退出码为 0
5. 反作弊条款：不得只创建空目录或空模块；smoke test 必须真实加载应用并验证导出接口存在

## Files

- Create: `rebar.config`
- Create: `apps/scrapling/src/scrapling.app.src`
- Create: `apps/scrapling/src/scrapling.erl`
- Create: `apps/scrapling/test/scrapling_bootstrap_tests.erl`
- Create: `apps/scrapling/test/fixtures/minimal.html`
- Create: `scripts/erlang-env.ps1`
- Create: `.gitignore`

## Steps

1. 写失败测试（红）
   - 新建 `apps/scrapling/test/scrapling_bootstrap_tests.erl`
   - 断言 `scrapling` 模块存在、导出 `version/0` 与 `info/0`
2. 跑到红
   - Run: `rebar3 eunit -m scrapling_bootstrap_tests`
   - Expected: 失败，原因是项目骨架与模块尚不存在
3. 实现最小骨架（绿）
   - 建立 `rebar.config`
   - 建立 `apps/scrapling/src/` 应用定义与最小 facade
   - 建立最小 fixture 与脚本骨架
4. 跑到绿
   - Run: `rebar3 eunit -m scrapling_bootstrap_tests`
   - Expected: PASS
5. 必要重构（仍绿）
   - 整理目录命名、统一环境变量口径、补 README 链接
6. E2E / 门禁
   - Run: `rebar3 eunit`
   - Expected: 当前仅 bootstrap tests 通过，退出码 0

## Risks

- 当前仓未初始化 git，Ship 前需要补齐
- `rebar3` 与 OTP 版本口径要尽早锁定，否则后续测试命令会漂移
- 如果一开始就把模块拆得过细，会放大空壳代码比例

