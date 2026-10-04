# 私信界面重构说明

## 架构

现有 Bilibili API、认证和 protobuf/REST 数据模型保持不变。页面拆为会话状态、展示适配和视图三个职责。

- `ConversationViewModel`：加载、分页、合并去重、发送、草稿、图片队列和表情数据。
- `ConversationMessageService`：包装现有 BiliAPI 调用，允许状态测试注入假服务；没有新增网络端点或认证方式。
- `MessagePresentationAdapter`：将原始消息转为文字、图片、分享卡片、系统提示或未支持类型提示；计算分组和时间分隔。
- `MessageTimelineView`：惰性列表、滚动跟随、历史加载位置保持、交互式键盘收起和面板拖动。
- `MessageComposer`：多行输入、原生连续选图、图片预览、Emoji/B站表情和发送入口。
- `MessageConversationView`：协调输入面板、系统导航和现有用户空间、视频、图片浏览路由。

内容解析按消息身份缓存；正文刷新不再重新解析全部 JSON。状态变化只更新相应发送状态，新增消息或历史页才重新计算相邻分组。图片仍使用现有异步加载和缓存。

## 交互规则

- 同一发送者、相邻时间差不超过 5 分钟且不跨日期/系统提示，形成消息组。
- 单条或组内最后一条文字消息有气泡尾巴；图片和分享卡片独立展示。
- 第一条有时间的消息、跨日期或间隔超过 15 分钟时显示时间分隔。
- 自己的文字消息使用应用现有 BiliPink 主题色，对方为系统灰色；跟随深色模式和增强对比度。
- 发送中的文字气泡使用本地稳定 ID；收到服务器确认后关联消息编号，刷新按编号去重。
- 只显示正在发送、已发送和发送失败；历史记录没有可靠状态时不补造状态。
- 成功发送使用系统触觉反馈；减少动态效果设置会关闭自定义的滚动和面板动画。
- 失败保留草稿；同内容手动重试复用本地气泡。网络超时仍提醒用户确认对方是否收到，避免重复发送。
- 连续选图立即进入待发送区，无额外确认。多图依次上传发送，成功后移除，失败图片和已上传数据保留。
- 图片发送保留文字草稿；发送期间继续输入不会被发送完成后的清理覆盖。
- 查看历史时不自动跳到新消息；自己发送后回到最新消息。
- 更早消息使用现有 `endSeqno` 参数，界面保存加载前的视觉偏移；边界消息去重。
- 系统键盘由 SwiftUI safe area 管理；显示自定义输入面板时忽略键盘 safe area，让面板占用同一空间，不再用负的键盘高度补偿。
- 恢复系统返回和导航转场；头像是独立的内容区，带系统材质渐变遮罩。
- 长按文字/卡片提供原生复制菜单；没有加入无后端支持的删除、撤回、Reaction。

## 修改文件

| 文件 | 职责或变化 |
| --- | --- |
| PiliPod/Views/MessageConversationView.swift | 从混合业务的大页面改为界面协调入口 |
| PiliPod/ViewModels/ConversationViewModel.swift | 会话业务和状态管理 |
| PiliPod/Services/ConversationMessageService.swift | 现有 API 的可测试包装 |
| PiliPod/Models/MessagePresentation.swift | 内容分类、稳定身份、分组、时间与状态 |
| PiliPod/Models/MessagePayload.swift | 保留并拆出原有内容和分享卡片解析 |
| PiliPod/Views/Messages/MessageTimelineView.swift | 列表、历史位置保持和滚动规则 |
| PiliPod/Views/Messages/MessageRow.swift | 按类型展示消息，接入原生菜单 |
| PiliPod/Views/Messages/MessageBubble.swift | 独立气泡 Shape、时间分隔和发送状态 |
| PiliPod/Views/Messages/MessageComposer.swift | 输入、原生连续选图、预览和表情 |
| PiliPod/Views/Messages/BiliMessageCard.swift | 独立 Bilibili 分享卡片 |
| PiliPod/Components/ConversationPanel.swift | 面板支持减少动态效果偏好 |
| PiliPod/Components/PrivateMessageText.swift | B站内嵌表情随 Dynamic Type 缩放并重新生成，取消旧加载后不覆盖新结果 |
| PiliPod/Components/PrivateMessagePhoto.swift | 按比例展示图片，缓存已选照片的解码结果 |
| PiliPod/Models/ConversationUITestFixture.swift | 仅 DEBUG 的离线界面测试数据及外观 |
| PiliPodTests/MessagePresentationTests.swift | 分组、时间、类型映射、身份及去重测试 |
| PiliPodTests/ConversationViewModelTests.swift | 失败重试、草稿保留、同步失败与图片部分失败 |
| PiliPodUITests/ConversationUITests.swift | 输入对齐、键盘、面板、选图、分页、复制和大字体深色测试 |
| PiliPod/PiliPodApp.swift | 测试入口使用真实 NavigationStack 推入会话，验证系统返回按钮 |
| PiliPod.xcodeproj/project.pbxproj | 测试 target 的最低系统版本与 App 对齐到 iOS 26.0 |

## 依赖和边界

没有新增第三方依赖，没有引入 Exyte/Chat、Swift Chat 或其他聊天 SDK。现有 GPLv3 许可证不变。

本次没有新增实时消息订阅或后台轮询。列表具有新增消息的跟随规则，但持续接收新消息需要后续单独实现。当前接入链路没有可靠的对方送达/已读回执映射，因此不显示这两种状态。

文字、B站表情、图片、现有视频/专栏/通用分享卡片保留。语音及其他未完整支持的类型显示提示，不将原始 JSON 作为气泡正文。现有视频卡片可打开视频；其他卡片的目标页面路由未增加。

分页响应目前只解码消息数组，是否还有下一页根据返回数量和序列号进度判断；没有伪造服务器 has-more 字段。真实账号下的边界分页、发送权限和服务端风控仍需真机验证。

## 验证

保留原有 14 个单元测试，新增 11 个展示层测试和 4 个会话状态测试。界面测试覆盖发送保持键盘、输入与按钮对齐、表情展开、原生连续选图、聊天拖动收起面板、历史 prepend 位置保持、从历史发送回到底部、历史请求迟到时仍保持已发送消息可见、原生复制菜单和深色大字体。

GitHub Actions 使用当前 Xcode 构建，运行单元和模拟器界面测试，导出截图，归档 Release 并生成未签名 IPA。实际运行结果及截图见本分支的 Verify private messages and build test IPA 工作流。

当前 Windows 工作环境无法运行 Instruments；本次没有声称完成 Instruments 真机性能分析。最低系统版本保持 iOS 26.0，运行过的模拟器版本以 CI 日志为准。

图片消息点击后复用评论区的 `FullscreenImageViewer` 全屏预览，沿用缩放、下拉关闭、图片保存和图像识别能力，不再维护私信独立的图片 sheet。发送按钮与自己的文字气泡统一使用现有 BiliPink 主题色资源。
