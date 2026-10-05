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
