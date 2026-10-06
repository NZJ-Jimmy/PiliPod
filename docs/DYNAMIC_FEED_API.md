# 动态页筛选接口核查（2026-10-06）

## 请求能力与采用方案

| 场景 | 请求 | 客户端处理 |
| --- | --- | --- |
| 全部关注 + 类别 | `feed/all?type=all/video/pgc/article` | 服务端类别筛选，一次一页 |
| 指定 UP + 全部 | `feed/all?host_mid=<UID>` | 服务端 UP 筛选，一次一页 |
| 指定 UP + 专栏 | `opus/feed/space?host_mid=<UID>&type=article` | 服务端组合筛选，一次一页；直接解析摘要 |
| 指定 UP + 投稿/番剧 | `feed/all?host_mid=<UID>` | 按顶层类型本地筛选，每次最多两页；后续历史由用户继续加载 |

以上路径前缀为 `https://api.bilibili.com/x/polymer/web-dynamic/v1/`。

`feed/all` 的 UP 筛选参数有 PiliPlus 源码依据，但需要设备上的登录 Cookie。此次环境没有设备登录态，无法实测 `host_mid` 与 `type` 同时生效，因此没有把这个未确认的组合用到生产请求中。

## 实测记录

使用无登录 Cookie 的公开请求，目标 UID 为文档示例 `645769214`，每个请求只获取首页，不扫描历史：

- `opus/feed/space?host_mid=645769214&type=article&web_location=333.1387`：HTTP 200、`code=0`，返回 5 条，`has_more=false`。
- 同接口 `type=all`：HTTP 200、`code=0`，返回 20 条，`has_more=true`。类别参数确实改变结果。
- `feed/all?host_mid=645769214&type=article`：HTTP 200、`code=-101`（账号未登录）。此结果不能证明组合支持或不支持。
- 普通 `feed/space` 探测：HTTP 412；没有重试，不能据此判断类别参数能力。

专栏摘要含 `opus_id`、`content`、`jump_url`、`cover`、`stat`；实测 `author` 可为 null、`pub_time` 可为空。页面补用已选 UP 的姓名与头像，保留真实 opus ID，跳转至服务端提供的正文 URL。摘要不含评论资源 ID，不伪造评论目标，也不为每张卡片追加详情请求。

## 请求和分页约束

- 去掉动态请求前额外的 WBI 密钥请求；PiliPlus 的关注流和实测空间专栏请求均无需此签名。
- 使用有效的浏览器 Origin、动态页 Referer；单次动态请求设置 12 秒超时。
- 本地组合筛选最多两页，两次请求间隔 750 毫秒；游标提交后可手动继续，不能从首页重扫。
- 空页且仍有游标时，显示“近期暂无匹配动态”和“查看更早动态”，不宣称整个历史没有结果。
- 分页失败后停止自动续查；相同筛选重新出现时不自动重试失败请求。手动刷新/重试仍可用。
- `-352` 显示风控校验失败，HTTP 412 显示请求暂时受限；保留已有卡片和游标。

## 来源

- [PiliPlus DynamicsHttp.followDynamic](https://github.com/bggRGjQaUbCoE/PiliPlus/blob/main/lib/http/dynamics.dart)：UP 模式传 host_mid，类别模式传 type。
- [PiliPlus API 路径](https://github.com/bggRGjQaUbCoE/PiliPlus/blob/main/lib/http/api.dart)：followDynamic 使用 feed/all。
- [空间图文接口文档](https://github.com/pskdje/bilibili-API-collect/blob/main/docs/opus/space.md)：host_mid 与 type=article、摘要响应字段。
- [动态接口错误码](https://goooler.github.io/bilibili-API-collect/docs/dynamic/detail.html)：-352 为风控校验失败。
