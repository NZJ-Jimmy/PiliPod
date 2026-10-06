# 分支与个人测试流程

整理日期：2026-10-05。仓库：NZJ-Jimmy/PiliPod；上游：BPTPW/PiliPod。

## 固定入口

- `main`：跟踪上游 `main`，目前未合入个人功能。
- `codex/integration`：个人组合测试入口，基于 `codex/merge-test-ipa-20261004`，另外合入原生私信。
- 整合分支只用于组合验证；整合 PR 保持 Draft，不直接合入 `main`。需要贡献上游时，从独立功能分支创建上游 PR。

## 功能清单

| 功能分支 | PR | 目标分支 | 整合状态 |
| --- | --- | --- | --- |
| `codex/my-library` | [#1](https://github.com/NZJ-Jimmy/PiliPod/pull/1) | `codex/integration` | 已合并（Merged） |
| `codex/gesture-lock` | [#3](https://github.com/NZJ-Jimmy/PiliPod/pull/3) | `codex/integration` | 已合并（Merged） |
| `codex/privacy-multi-account` | [#4](https://github.com/NZJ-Jimmy/PiliPod/pull/4) | `codex/integration` | 已合并（Merged） |
| `codex/video-detail-back-gesture` | [#5](https://github.com/NZJ-Jimmy/PiliPod/pull/5) | `codex/integration` | 已合并（Merged） |
| `codex/avplayer-navigation-stutter` | [#6](https://github.com/NZJ-Jimmy/PiliPod/pull/6) | `codex/integration` | 已合并（Merged） |
| `codex/video-detail-comment-preview` | [#7](https://github.com/NZJ-Jimmy/PiliPod/pull/7) | `codex/integration` | 已合并（Merged） |
| `codex/video-danmaku-controls` | [#8](https://github.com/NZJ-Jimmy/PiliPod/pull/8) | `codex/integration` | 已合并（Merged） |
| `codex/my-page-layout` | [#9](https://github.com/NZJ-Jimmy/PiliPod/pull/9) | `codex/integration` | 已合并（Merged），功能依赖 #1 |
| `codex/private-message-native` | [#10](https://github.com/NZJ-Jimmy/PiliPod/pull/10) | `codex/integration` | 已合并（Merged） |

2026-10-05：#1、#3–#10 已正式合并到 `codex/integration`，GitHub 状态均为 Merged。为补录先前的本地整合，每个功能分支增加了一条不改代码的空提交，再通过 PR 合并；整合分支文件内容与补录前完全一致。#11 仍为指向 main 的整合 Draft PR，不合并。#9 的功能仍依赖 #1；将来向上游贡献时另开独立 PR，按依赖安排提交顺序。

## 历史分支

- `codex/merge-three-branches`、`codex/merge-test-ipa-20261004`：保留旧整合和 IPA 构建记录；后续组合更新统一进入 `codex/integration`。
- `codex/private-message-send`、`codex/private-message-swift-chat`：已弃用的 Swift Chat 实验；#2 已关闭，替代 PR 为 #10。
- `swift-chat-demo-build`：独立 Swift Chat 演示，保留，不纳入原生功能整合。
- `localization`、`copilot/add-function-comments-video-detail`：保留，本次不纳入个人功能整合。
- 所有原始分支与现有 worktree 保留，避免打断正在进行的聊天与开发。

## 后续操作

新功能从最新的 `main` 创建 `codex/<功能名>`，推送后创建指向自己 `codex/integration` 的 Draft PR；准备组合测试时通过该 PR 合并。功能分支保持独立，不从整合分支开发。依赖其他功能时明确标注，按需要先使用依赖分支作为 base；提交上游时另开 PR。已合并的 PR 不复用来跟踪后续新增提交，应创建新的增量 PR。

通过 PR 合并是新的默认流程。需要手动整合时，以下命令仍可使用，但应核实相应 PR 的状态：

```powershell
git fetch origin
git switch codex/integration
git merge --no-ff origin/codex/<功能名>
git push origin codex/integration
```

冲突只在整合分支解决，保留各功能的行为。不要把整合分支合回功能分支。未发布的冲突处理可以修正后再推送，已发布的整合历史不要 force push。

`Verify integration and build test IPA` 在整合分支推送时运行全部单元与 UI 测试，初始化测试照片库，并归档 Release 未签名 IPA。组合编译、测试与真实账号行为需以 Actions 和设备验证为准，合入并不等于测试通过。

需要移除某个已整合功能时，从明确的基线新建一条整合分支，仅合入要保留的功能；保留旧分支作为历史记录，避免覆盖共享测试历史。

## 动态页筛选（2026-10-05）

- 分支：`codex/dynamic-filters`，从已同步的 `origin/main`（`72ea3b6`）创建，无个人功能依赖。
- 功能：原生 SwiftUI UP 主列表、关注搜索选择器、全部/投稿/番剧/专栏组合筛选；保留现有卡片导航。
- PR：[#12](https://github.com/NZJ-Jimmy/PiliPod/pull/12)，个人 fork Draft，目标为 `codex/integration`；尚未整合。
- 验证：[`Verify dynamic filters`](https://github.com/NZJ-Jimmy/PiliPod/actions/runs/37266052575) 在代码提交 `3fce42c` 上编译成功，12 项单元测试全部通过（含 6 项新增筛选测试）。此后仅补充分支记录；真实账号及真机交互尚未验证。
- 合并预检查：与整合分支存在 `BRANCHES.md` 新增记录及 `BiliAPI.fetchAllDynamics` 签名附近的冲突；准备组合测试时仅在整合分支解决，保留多账号请求行为。
- 2026-10-05：按用户要求直接在功能分支构建独立未签名测试 IPA，不做整合；流水线增加 Release 归档、IPA 校验及产物上传。构建提交 `5892e3b` 已通过 12 项单元测试与 Release 归档；[构建记录](https://github.com/NZJ-Jimmy/PiliPod/actions/runs/37290170025)，[IPA 产物](https://github.com/NZJ-Jimmy/PiliPod/actions/runs/37290170025/artifacts/11336486867)。本地下载后 SHA-256、Payload 结构及 arm64 可执行文件校验通过，真机尚未验证。
- 2026-10-05 后续修复：刷新原子替换结果、自动跨页查找；刷新控件仅挂在纵向列表；返回时复用筛选结果与滚动位置；视频卡片及动态详情接入原生 zoom 转场。新增取消刷新/页面返回/跨页单元测试和三项固定数据 UI 回归测试，独立 IPA 验证待完成。
- 2026-10-05 修复版本：使用原生 List 隔离刷新；刷新事务保留旧结果并自动跨页查找；同筛选返回复用列表及游标；视频使用原生导航滑动动画，并增加限定左侧 32 点起手的 SwiftUI 返回手势。代码提交 `a3c90de` 的 15 项单元测试、3 项动态页 UI 回归及 Release 归档全部通过；本地 SHA-256、Payload 与 arm64 校验通过。[构建记录](https://github.com/NZJ-Jimmy/PiliPod/actions/runs/37299846032)，[修复版 IPA](https://github.com/NZJ-Jimmy/PiliPod/actions/runs/37299846032/artifacts/11341627959)。不做整合，真机仍待测试。
- 2026-10-05 原生卡片转场：按用户要求替换普通滑动转场，视频、直播、专栏/其他网页预览、文字/图文动态详情及图片全屏查看统一接入原生 zoom，来源按动态 ID 区分。动态页的视频和直播路径停用自定义返回手势代理与拖动兜底；专栏使用应用内 WKWebView。代码提交 `1490158` 的 15 项单元测试、5 项 UI 测试（包括原生捏合返回、专栏与文字动态返回）及 Release 归档全部通过；本地 SHA-256、Payload 与 arm64 校验通过。[构建记录](https://github.com/NZJ-Jimmy/PiliPod/actions/runs/37305070783)，[原生 zoom 测试 IPA](https://github.com/NZJ-Jimmy/PiliPod/actions/runs/37305070783/artifacts/11343822350)。未整合、未签名，真实账号和真机仍待验证。
- 2026-10-06 接口与分页修复：实测并改用 `opus/feed/space?host_mid=…&type=article` 获取指定 UP 专栏摘要，不扫描全部动态或逐条请求详情。指定 UP 的投稿/番剧暂保留本地类型判断，每次最多两页、间隔 750ms，之后手动接续游标；停止失败后的自动重试。移除多余 WBI 密钥请求，修正请求头、增加 12 秒超时，并明确显示 -352/HTTP 412。调研依据和登录态验证限制见 `docs/DYNAMIC_FEED_API.md`。代码提交 `7b3b47f` 的 19 项单元测试、6 项 UI 回归及 Release 归档全部通过；本地 SHA-256、Payload 与 arm64 校验通过。[构建记录](https://github.com/NZJ-Jimmy/PiliPod/actions/runs/37478761350)，[接口修复版 IPA](https://github.com/NZJ-Jimmy/PiliPod/actions/runs/37478761350/artifacts/11420972170)。未整合、未签名；真实账号与真机仍待验证。
- 2026-10-06 授权账号接口验证：两个登录态均有效；同一关注 UP 的首页 12 条，在组合参数下分别返回 2 条专栏、10 条投稿，作者及类型均正确。投稿/番剧改用 host_mid + type；移除客户端类型筛选和自动跨页搜索，每次只请求一页，空页手动接续游标。番剧尚无非空样本，未复现 -352/HTTP 302；新独立 IPA 编译验证进行中。
- 2026-10-06 新组合 API 版本 b933819 编译及 19 项单元测试通过，6 项 UI 测试中下拉刷新操作未触发更新，其他 5 项通过（包含视频原生返回和滚动位置）。保留失败记录，UI 测试改为列表内部明确起落点拖拽，保持刷新结果断言后重新验证。
- 2026-10-06 重跑 9257df5：19 项单元测试、下拉刷新及其他 4 项 UI 测试通过；视频测试在打开详情后查询背后卡片 hittability 时由 XCTest 报 Activation point invalid。改为检查详情页存在、原生捏合退出后检查详情消失，再验证原卡片可点击、原位置及未刷新；产品转场行为未修改，重新验证独立 IPA。
- 2026-10-06 服务端组合筛选最终验证：提交 1c90a7d 的 19 项单元测试、6 项 UI 回归（包括刷新、原生捏合返回和滚动位置）及 Release 归档全部通过。已下载独立未签名 IPA，来源提交、SHA-256、Payload 与 arm64 校验通过。[构建记录](https://github.com/NZJ-Jimmy/PiliPod/actions/runs/37485812590)，[IPA 产物](https://github.com/NZJ-Jimmy/PiliPod/actions/runs/37485812590/artifacts/11423816501)。授权只读真实账号 API 验证已完成，番剧无非空样本，-352/HTTP 302 未复现，真机 UI 仍待测试；未整合。
