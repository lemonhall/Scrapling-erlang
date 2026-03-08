# Scrapling-erlang

`Scrapling-erlang` 的目标，是把本机源码仓 `E:\development\Scrapling` 在 **Erlang/OTP** 上做成能力对等实现。

当前时间点是 **2026-03-08**，本仓库还处于**文档先行 / 塔山计划**阶段，尚未开始 Erlang 实现。

## 当前状态

- 源项目基线：本机 `E:\development\Scrapling`
- 源项目版本快照：`scrapling/__init__.py` 显示 `0.4.1`
- 当前仓状态：空目录起步，先冻结愿景、PRD、v1 计划与追溯矩阵
- 默认目标：让 **Erlang / BEAM 社区** 获得与源项目等价的解析、抓取、蜘蛛、CLI、AI/MCP 能力

> 注：原始口述里出现了“让 kotlin 社区拥有……”这句话。结合仓库名 `Scrapling-erlang` 与本次任务上下文，本仓默认按 **Erlang/BEAM 对等实现** 理解；若后续需要同时交付 Kotlin 对等版本，按 ECN 追加，不在本轮偷偷扩范围。

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

- 不允许擅自降低“像素级复刻”的要求
- 不允许把“写了文档”当成“功能已实现”
- 不允许先实现再回填追溯矩阵
- 每一项源项目公开能力都必须进入：`PRD → v1 计划 → 测试入口 → 证据`

## 下一步

第一阶段不是直接写 Erlang 代码，而是先完成：

1. 冻结源项目能力面与约束
2. 建立本仓 PRD / v1 计划 / 追溯矩阵
3. 以 `v1-repo-bootstrap` 为第一条执行计划启动项目骨架

