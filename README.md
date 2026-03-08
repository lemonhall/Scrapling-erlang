# Scrapling-erlang

`Scrapling-erlang` 的目标，是把本机源码仓 `E:\development\Scrapling` 在 **Erlang/OTP** 上做成能力对等实现。

当前时间点是 **2026-03-08**，本仓库已进入 **v1-repo-bootstrap** 实施阶段，并已完成最小 Erlang 骨架与 smoke test。

## 当前状态

- 源项目基线：本机 `E:\development\Scrapling`
- 源项目版本快照：`scrapling/__init__.py` 显示 `0.4.1`
- 当前仓状态：已建立 `rebar3` 骨架、最小 facade、环境脚本、fixture 与 bootstrap eunit，并已验证通过
- 默认目标：让 **Erlang / BEAM 社区** 获得与源项目等价的解析、抓取、蜘蛛、CLI、AI/MCP 能力

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

当前阶段已经完成文档矩阵与 bootstrap，下一步进入 parser / adaptive：

1. 进入 `docs/plan/v1-parser-adaptive.md`
2. 建立 `Selector / Selectors` 与 adaptive 存储的红绿测试闭环
3. 持续更新 `docs/plan/v1-index.md` 的追溯矩阵与里程碑状态
