# v1-cli-ai-docs

## Goal

建立 CLI、交互式 shell、MCP 接口与文档出口，让 Scrapling-erlang 不只是“库”，而是一套可被终端、脚本与 AI 工具链复用的完整能力面。

## PRD Trace

- REQ-0001-010
- REQ-0001-011
- REQ-0001-012

## Scope

### 做什么

- 建立 `scrapling_cli` 入口与最小命令集
- 建立 shell / extract / mcp 的能力映射
- 为每个核心能力补最小示例与文档入口
- 把 PRD / 计划 / 测试 / 证据链真正闭合

### 不做什么

- 不在本计划里重新设计源项目定位
- 不在本计划里跳过测试只写 README
- 不在本计划里替代 parser / fetcher / spider 的真实实现

## Acceptance

1. CLI 至少覆盖 `install`、`extract`、`shell`、`mcp` 的等价入口或明确映射
2. 每个命令都有最小测试与最小示例
3. MCP 接口能暴露定向提取能力并返回结构化结果
4. README 与文档入口能把用户带到 parser / fetchers / spiders / CLI / AI 的对应页面
5. 反作弊条款：不得只有帮助文本而没有真实命令分派；不得只有 README 而没有测试入口

## Files

- Create: `apps/scrapling/src/scrapling_cli.erl`
- Create: `apps/scrapling/src/scrapling_shell.erl`
- Create: `apps/scrapling/src/scrapling_mcp.erl`
- Create: `apps/scrapling/test/scrapling_cli_tests.erl`
- Create: `apps/scrapling/test/scrapling_mcp_tests.erl`
- Modify: `README.md`
- Create: `docs/cli/overview.md`
- Create: `docs/ai/mcp-server.md`
- Create: `docs/parsing/main_classes.md`
- Create: `docs/fetching/choosing.md`
- Create: `docs/spiders/getting-started.md`

## Steps

1. 写失败测试（红）
   - `scrapling_cli_tests.erl` 覆盖命令分派与参数校验
   - `scrapling_mcp_tests.erl` 覆盖最小提取流程
2. 跑到红
   - Run: `rebar3 eunit -m scrapling_cli_tests`
   - Expected: 失败，原因是 CLI / MCP 模块不存在
3. 实现最小 CLI / MCP（绿）
   - 先落命令分派，再落与 parser / fetcher / spider 的串接
4. 跑到绿
   - Run: `rebar3 eunit -m scrapling_cli_tests`
   - Expected: PASS
5. 实现文档出口与样例（仍绿）
   - 补 README、docs 分类页、最小示例
6. 再跑到绿
   - Run: `rebar3 eunit -m scrapling_mcp_tests`
   - Expected: PASS
7. 必要重构（仍绿）
   - 统一错误信息、帮助文本、命令参数命名
8. E2E / 门禁
   - Run: `rebar3 eunit -m scrapling_cli_tests -m scrapling_mcp_tests`
   - Expected: PASS
   - Run: `rebar3 eunit`
   - Expected: PASS

## Risks

- CLI 参数设计如果与后续模块契约不一致，会造成文档与实现一起返工
- MCP 需要尽早确定结构化返回格式，否则很难稳定接入上层工具
- 文档如果不跟测试一起更新，会重新回到“功能和说明脱钩”的旧问题

