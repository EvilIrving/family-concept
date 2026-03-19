# Claude 使用规范

本文件保留为 Claude 入口兼容层。

- 事实来源以 [docs/family_v1_design.md](/Users/cain/Documents/code/flutter-family-concept/docs/family_v1_design.md) 为准
- 项目介绍以 [README.md](/Users/cain/Documents/code/flutter-family-concept/README.md) 为准
- Codex 代理约束以 [AGENTS.md](/Users/cain/Documents/code/flutter-family-concept/AGENTS.md) 为准

## Storage 路径约定

- Bucket: `dishes`
- 路径格式: `{family_id}/{dish_id}.jpg`
- RLS 策略通过路径第一段提取 `family_id` 进行权限校验
- Flutter 上传代码必须遵守此格式

## 当前实现状态

- 仓库已包含完整 Flutter 工程
- 入口在 `lib/main.dart`
- 路由在 `lib/core/router/app_router.dart`
- 数据访问在 `lib/shared/repositories/`
- 共享模型在 `lib/shared/models/app_models.dart`

## 运行要求

- 通过 `--dart-define` 提供 `SUPABASE_URL` 与 `SUPABASE_ANON_KEY`
- 可选 `APP_BASE_URL` 用于分享链接
- 用户名登录基于 Supabase email/password 的映射方案



## Flutter 


不要动画，不要使用 


交互设计：

操作像现实一样直接（Direct Manipulation）

反馈几乎是瞬时的（Immediate Feedback）

出错可以轻松恢复（Forgiveness）

整个过程连续无阻（Continuity）

无阻塞（少弹窗）

无中断（少等待）

无跳跃（连续过渡）

少一些page，可以多使用 sheet方式 填写信息


