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
