# Codex 使用规范

## 适用范围

- 适用于本仓库内的 Codex 工作流
- 事实来源以 [docs/family_v1_design.md](/Users/cain/Documents/code/flutter-family-concept/docs/family_v1_design.md) 为准
- 项目介绍与导航以 [README.md](/Users/cain/Documents/code/flutter-family-concept/README.md) 为准

## 工作约束

### Storage 路径约定

- Bucket: `dishes`
- 路径格式: `{family_id}/{dish_id}.jpg`
- RLS 策略通过路径第一段提取 `family_id` 进行权限校验
- Flutter 上传代码必须遵守此格式

---

## 模式行为准则

### Ask/问答模式

- 不得主动修改或编写代码（除非用户明确要求）
- 不添加测试代码
- 不执行 npm/pnpm/yarn dev/build 等命令

### 智能体/Agent 模式

- 可直接操作代码
- 精简分析，直接给出结论

## 输出格式要求

当要求使用 plaintext 格式时：

```plaintext
<输出内容>
```

- 不添加任何开头语、结束语或客套话
- 保持简洁明了

避免使用 emoji
