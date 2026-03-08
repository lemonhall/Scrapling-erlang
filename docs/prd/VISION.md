# Vision

## 项目愿景

`Scrapling-erlang` 要成为本机源项目 `E:\development\Scrapling` 的 **Erlang/OTP 对等实现**：

- 让 BEAM 生态拥有与 Scrapling 相同等级的 HTML 解析、元素定位、动态抓取、反爬抓取、会话管理、Spider 编排、CLI 与 AI/MCP 集成能力
- 让用户能够用 **Erlang 原生方式** 获得与源项目 **一一对应的能力面、行为语义、文档入口、测试证据**
- 让“像素级复刻”落实为**可追溯、可验证、不可偷工减料**的工程纪律，而不是口号

## 成功长相

当以下条件全部满足时，才算愿景达成：

1. 源项目 `0.4.1` 的每一个公开能力都能在本仓找到对应的 `Req ID`
2. 每一个 `Req ID` 都能在 `docs/plan/` 找到执行计划、测试入口与证据位置
3. Erlang 用户可以完成以下核心路径：
   - 解析 HTML 并进行 CSS / XPath / 文本 / 正则 / 导航式选择
   - 进行静态 HTTP 抓取，并复用 session / cookies / headers / proxy
   - 进行动态与 stealth 浏览器抓取，并返回统一响应对象
   - 用 Spider API 运行并发 crawl，支持 pause / resume / checkpoint / stream / stats
   - 用 CLI 与 MCP 接口做交互式抓取与数据提取
4. 所有未完成项都必须显式进入差异列表或 ECN，不能“默认以后再说”

## 目标用户

- 需要在 Erlang/OTP 中长期运行采集服务的工程师
- 需要动态网页抓取与反爬能力的 BEAM 团队
- 希望把抓取能力作为 OTP 服务、流水线、AI 工具链一部分的开发者

## 非目标

- 不强求 Python 语法字面一模一样；要求的是**能力与语义对等**，不是语法抄写
- 不在没有 ECN 的情况下删减源项目公开能力
- 不把文档占位、空壳模块、假实现视为“已经有这项能力”

## 关键约束

- 源项目快照基线固定为 **2026-03-08 本机 `E:\development\Scrapling`**
- 当前源项目版本号为 `0.4.1`
- 默认开发环境为 Windows 11 + `pwsh.exe` + Erlang/OTP 28 + `rebar3`
- 本项目遵循塔山循环：`愿景 → PRD → vN 计划 → TDD/E2E → 差异回顾 → 下一轮`

## 当前阶段

- **2026-03-08**：完成文档矩阵建立，冻结第一版 PRD 与 v1 计划
- 真正的 Erlang 实现从 `docs/plan/v1-repo-bootstrap.md` 开始执行

