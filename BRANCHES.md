# 分支与个人测试流程

整理日期：2026-10-05。仓库：NZJ-Jimmy/PiliPod；上游：BPTPW/PiliPod。

## 固定入口

- `main`：跟踪上游 `main`，目前未合入个人功能。
- `codex/integration`：个人组合测试入口，基于 `codex/merge-test-ipa-20261004`，另外合入原生私信。
- 整合分支只用于组合验证；整合 PR 保持 Draft，不直接合入 `main`。需要贡献上游时，从独立功能分支创建上游 PR。

## 功能清单

| 功能分支 | PR | 目标分支 | 整合状态 |
| --- | --- | --- | --- |
| `codex/my-library` | [#1](https://github.com/NZJ-Jimmy/PiliPod/pull/1) | `main` | 已纳入 |
| `codex/gesture-lock` | [#3](https://github.com/NZJ-Jimmy/PiliPod/pull/3) | `main` | 已纳入 |
| `codex/privacy-multi-account` | [#4](https://github.com/NZJ-Jimmy/PiliPod/pull/4) | `main` | 已纳入 |
| `codex/video-detail-back-gesture` | [#5](https://github.com/NZJ-Jimmy/PiliPod/pull/5) | `main` | 已纳入 |
| `codex/avplayer-navigation-stutter` | [#6](https://github.com/NZJ-Jimmy/PiliPod/pull/6) | `main` | 已纳入 |
| `codex/video-detail-comment-preview` | [#7](https://github.com/NZJ-Jimmy/PiliPod/pull/7) | `main` | 已纳入 |
| `codex/video-danmaku-controls` | [#8](https://github.com/NZJ-Jimmy/PiliPod/pull/8) | `main` | 已纳入 |
| `codex/my-page-layout` | [#9](https://github.com/NZJ-Jimmy/PiliPod/pull/9) | `codex/my-library` | 已纳入，依赖 #1 |
| `codex/private-message-native` | [#10](https://github.com/NZJ-Jimmy/PiliPod/pull/10) | `main` | 已纳入 |

#4–#10 新建为 Draft。#1 与 #3 保留原来的审查状态。#1 合入自己的 `main` 后，将 #9 的 base 改为 `main`。

## 历史分支

- `codex/merge-three-branches`、`codex/merge-test-ipa-20261004`：保留旧整合和 IPA 构建记录；后续组合更新统一进入 `codex/integration`。
- `codex/private-message-send`、`codex/private-message-swift-chat`：已弃用的 Swift Chat 实验；#2 已关闭，替代 PR 为 #10。
- `swift-chat-demo-build`：独立 Swift Chat 演示，保留，不纳入原生功能整合。
- `localization`、`copilot/add-function-comments-video-detail`：保留，本次不纳入个人功能整合。
- 所有原始分支与现有 worktree 保留，避免打断正在进行的聊天与开发。

## 后续操作

新功能从最新的 `main` 创建 `codex/<功能名>`，推送后创建自己的 Draft PR；如依赖其他功能，明确标注依赖并选择相应 base。

更新组合版本时：

```powershell
git fetch origin
git switch codex/integration
git merge --no-ff origin/codex/<功能名>
git push origin codex/integration
```

冲突只在整合分支解决，保留各功能的行为。不要把整合分支合回功能分支。未发布的冲突处理可以修正后再推送，已发布的整合历史不要 force push。

`Verify integration and build test IPA` 在整合分支推送时运行全部单元与 UI 测试，初始化测试照片库，并归档 Release 未签名 IPA。组合编译、测试与真实账号行为需以 Actions 和设备验证为准，合入并不等于测试通过。

需要移除某个已整合功能时，从明确的基线新建一条整合分支，仅合入要保留的功能；保留旧分支作为历史记录，避免覆盖共享测试历史。
