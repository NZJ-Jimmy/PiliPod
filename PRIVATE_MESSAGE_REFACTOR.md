# Swift Chat 私信界面说明

> **Deprecated**：本分支已弃用，仅保留历史。后续私信开发及测试 IPA 使用 `codex/private-message-native`，不再继续迭代 Swift Chat 方案。

## 分支选择

- `codex/private-message-swift-chat`：本分支，基于 `1d245f0`，使用 Swift Chat SDK。
- `codex/private-message-native`：基于接入 SDK 前的最后提交 `0c711a1`，使用仓库内的原生 SwiftUI 开源组件，没有第三方聊天 SDK，也未引入 Exyte/Chat。
- `codex/private-message-send`：保留拆分前的历史及已有 PR；其 Swift Chat 方案同样已弃用。

## 当前实现

会话入口为 `PiliPod/Views/Messages/SwiftChatConversationView.swift` 中的 `MessageConversationView`。消息列表、输入栏、照片选择、键盘、滚动及发送生命周期由 Swift Chat 的 `Chat` 和 `onChatSend` 管理。

`ConversationViewModel`、`ConversationMessageService` 和原有 Bilibili API 负责加载、分页、合并去重、文字与图片发送。`SwiftChatMediaData` 读取 SDK 提供的照片文件；发送失败保留内容和上传结果，提供手动重试。没有新增网络端点或认证方式。

`MessagePresentation` 和 `MessagePayload` 继续适配 Bilibili 消息内容。B站表情使用 `PrivateMessageText` 展示，分享卡片使用 `BiliMessageCard`，图片使用 SDK 媒体展示。表情入口在工具栏，表情 sheet 复用 `MessageComposer.emotePanel`；普通文字和照片输入使用 SDK 输入栏。

历史中保留的 `MessageTimelineView`、`MessageRow`、`MessageBubble` 是原生版本的组件，本分支的会话入口没有使用它们。原生组件的分组、气泡尾巴和滚动规则不代表 SDK 的行为；完整原生实现说明见 `codex/private-message-native` 分支。

## 依赖和边界

本分支通过 Swift Package Manager 接入 Swift Chat 1.0.6，并固定版本提交。SDK 为闭源二进制，其许可证和个人测试用途见 `THIRD_PARTY_NOTICES.md`、`Licenses/SwiftChat-LICENSE.md` 和 README；上游 GPLv3 许可证及版权声明保留。

本次没有新增实时消息订阅、后台轮询或对方送达/已读回执。语音及其他未完整支持的类型显示提示。真实账号发送权限、分页边界和服务端风控仍需设备验证。最低系统版本保持 iOS 26.0。

## 验证

本分支工作流 `.github/workflows/verify-private-message.yml` 仅保留手动触发，运行 `PiliPodTests` 和 `SwiftChatConversationUITests`，导出截图并归档未签名 IPA。Deprecated 分支不再因 push 自动构建。

拆分前代码提交 `1d245f0` 的 Actions 已通过 33 项单元测试、2 项界面测试、Release 归档及 IPA 打包：
https://github.com/NZJ-Jimmy/PiliPod/actions/runs/37217327933

此次拆分只调整分支说明和 CI 触发分支，没有修改 Swift 或 Xcode 工程；拆分后的运行结果以各分支 Actions 为准。Windows 环境未运行 Xcode 或 Instruments。
