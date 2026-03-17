# Claude 使用规范

## 项目简介

私厨点菜 App — 面向私厨/家庭/小型聚餐场景的点菜工具。

核心场景：厨师（管理员）创建菜单，食客扫码加入订单、自主点菜，厨师驱动制作流程。

核心抽象：User → Order → Dish（订单是可分享的协作容器）

## 技术栈

- 前端：Flutter（iOS + Android）
- 后端：Supabase
  - 数据库：PostgreSQL
  - 认证：Supabase Auth（username + password）
  - 存储：Supabase Storage（菜品图片）
  - 实时同步：Supabase Realtime
- 路由：GoRouter
- 状态管理：Riverpod

## 核心数据模型

| 表名 | 说明 |
|------|------|
| profiles | 用户档案（username, avatar_url, is_admin） |
| dishes | 菜品（name, category, image_url, ingredients JSON） |
| orders | 订单（status, share_token, current_round） |
| order_members | 订单成员（order_id, user_id） |
| order_items | 订单菜品项（dish_id, quantity, status, order_round） |

### 枚举类型

- order_status: `ordering` | `placed` | `finished`
- item_status: `waiting` | `cooking` | `done`

### 关键约束

- 同一用户同一时间只能存在于一个活跃订单（trigger 校验）
- 管理员是全局角色，通过 profiles.is_admin 标记

## 项目结构

```
lib/
├── core/           # 基础设施（supabase, router, theme, utils）
├── features/       # 功能模块（auth, menu, order, join, setting）
└── shared/         # 通用组件和 models
```

详见 README.md

## 开发阶段

Phase 1-8，详见 README.md「开发顺序」章节

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
