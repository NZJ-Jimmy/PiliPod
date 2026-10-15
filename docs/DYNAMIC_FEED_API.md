# 动态页筛选接口核查（2026-10-06）

## 请求能力与采用方案

| 场景 | 请求 | 客户端处理 |
| --- | --- | --- |
| 全部关注 + 类别 | `feed/all?type=all/video/pgc/article` | 服务端类别筛选，一次一页 |
| 指定 UP + 全部 | `feed/all?host_mid=<UID>` | 服务端 UP 筛选，一次一页 |
| 指定 UP + 专栏 | `opus/feed/space?host_mid=<UID>&type=article` | 服务端组合筛选，一次一页；直接解析摘要 |
| 指定 UP + 投稿/番剧 | `feed/all?host_mid=<UID>&type=video/pgc` | 服务端组合筛选，一次一页 |

以上路径前缀为 `https://api.bilibili.com/x/polymer/web-dynamic/v1/`。

`feed/all` 的 UP 筛选参数有 PiliPlus 源码依据。用户提供登录态后，已实测 `host_mid` 与 `type` 同时生效，因此投稿/番剧改用组合参数，删除客户端类型筛选和自动跨页查找。指定 UP 的专栏继续使用已验证的空间专栏摘要接口。

## 实测记录

使用无登录 Cookie 的公开请求，目标 UID 为文档示例 `645769214`，每个请求只获取首页，不扫描历史：

- `opus/feed/space?host_mid=645769214&type=article&web_location=333.1387`：HTTP 200、`code=0`，返回 5 条，`has_more=false`。
- 同接口 `type=all`：HTTP 200、`code=0`，返回 20 条，`has_more=true`。类别参数确实改变结果。
- `feed/all?host_mid=645769214&type=article`：HTTP 200、`code=-101`（账号未登录）。此结果不能证明组合支持或不支持。
- 普通 `feed/space` 探测：HTTP 412；没有重试，不能据此判断类别参数能力。

专栏摘要含 `opus_id`、`content`、`jump_url`、`cover`、`stat`；实测 `author` 可为 null、`pub_time` 可为空。页面补用已选 UP 的姓名与头像，保留真实 opus ID，跳转至服务端提供的正文 URL。摘要不含评论资源 ID，不伪造评论目标，也不为每张卡片追加详情请求。

## 授权登录态实测

用户授权只读测试，两个导入账号的 nav 均为 code=0、isLogin=true。只向 B 站发送 Cookie，不保存凭据或动态正文；以下仅记录去身份化汇总。

对同一位已关注 UP 的首页比较（每次只取一页）：

| 参数 | code | 条数 | 类型 | 非目标作者 |
| --- | --- | --- | --- | --- |
| host_mid | 0 | 12 | 专栏 2、投稿 10 | 0 |
| host_mid + type=article | 0 | 2 | 全部专栏 | 0 |
| host_mid + type=video | 0 | 10 | 全部投稿 | 0 |
| host_mid + type=pgc | 0 | 0 | 空页，has_more=true | 0 |

另一次专栏分页校验：首页 1 条专栏、下一页 0 条，均 code=0、has_more=true，游标推进，非目标作者/类型均为 0。空页不能当作历史耗尽，也不能凭 has_more 自动持续扫描。番剧返回空页，仅证明参数被接受，尚无非空番剧样本。

截图所选 UP 也在第二个账号的 UP 列表中找到：空间专栏接口 code=0、0 条、has_more=false，单次约 119ms；关注流首页 12 条均为视频，同一 UP 的 type=article 为 0 条、has_more=true。两条路径均无其他作者。空间专栏路径可直接结束该筛选，无需扫描其视频历史。耗时仅代表本次测试环境，不代表手机网络表现。

文档示例 UID 在当前关注流中返回空页，不能用该样本判断组合能力。全部关注的 type=article 返回 20 条，均为专栏。测试未复现 -352 或 HTTP 302；截图 -352 是业务风控码，不是 HTTP 302。

## 请求和分页约束

- 去掉动态请求前额外的 WBI 密钥请求；PiliPlus 的关注流和实测空间专栏请求均无需此签名。
- 使用有效的浏览器 Origin、动态页 Referer；单次动态请求设置 12 秒超时。
- 所有筛选每次只请求一页，无客户端类型筛选、无自动历史扫描；空页提交游标后可手动继续，不能从首页重扫。
- 空页且仍有游标时，显示“近期暂无匹配动态”和“查看更早动态”，不宣称整个历史没有结果。
- 分页失败后停止自动续查；相同筛选重新出现时不自动重试失败请求。手动刷新/重试仍可用。
- `-352` 显示风控校验失败，HTTP 412 显示请求暂时受限；保留已有卡片和游标。

## 来源

- [PiliPlus DynamicsHttp.followDynamic](https://github.com/bggRGjQaUbCoE/PiliPlus/blob/main/lib/http/dynamics.dart)：UP 模式传 host_mid，类别模式传 type。
- [PiliPlus API 路径](https://github.com/bggRGjQaUbCoE/PiliPlus/blob/main/lib/http/api.dart)：followDynamic 使用 feed/all。
- [空间图文接口文档](https://github.com/pskdje/bilibili-API-collect/blob/main/docs/opus/space.md)：host_mid 与 type=article、摘要响应字段。
- [动态接口错误码](https://goooler.github.io/bilibili-API-collect/docs/dynamic/detail.html)：-352 为风控校验失败。
