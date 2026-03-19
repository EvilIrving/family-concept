# 私厨点菜 App — Product Requirements Document

## 一、产品定位

面向私厨 / 家庭 / 小型聚餐场景的点菜工具。

核心场景：

- 厨师或家庭成员先进入一个家庭空间
- 家庭管理员维护本家庭菜单
- 食客通过家庭上下文创建订单或加入订单
- 家庭成员与访客围绕同一个订单协作点菜
- 厨师驱动制作流程并最终结束订单

非目标：

- 不是菜谱工具
- 不是通用家庭管理系统
- 不是对外商业餐饮系统

## 二、核心抽象

`User -> Family -> Order -> OrderItem -> Dish`

说明：

- `Family` 是租户边界
- 菜单、订单、成员都从属于家庭
- `Order` 是家庭内可分享的协作容器
- `Dish` 是家庭级菜单资源，不再是全局资源

## 三、核心设计原则

- 业务权限属于家庭成员关系，不属于全局用户。
- `profiles.is_admin` 如保留，仅表示平台运维角色，不参与业务授权。
- 新用户注册后必须先创建家庭或加入家庭，才能进入主应用。
- 访客不是家庭成员，只是订单级临时参与者。
- 家庭邀请码与订单分享链接是两套不同机制。

## 四、用户与角色

### 账号体系

- 登录方式：`username + password`
- `username` 全局唯一
- 用户基础信息：`username`、`avatar_url`、`account_id`
- v1 不做邮箱、第三方登录、找回密码

### 角色分层

#### 平台角色

- `profiles.is_admin`
- 仅用于平台运维或手动数据处理
- 不用于菜单管理、订单管理、家庭成员管理

#### 家庭角色

- `family_members.role = owner | admin | member`

权限边界：

- `owner`
  - 管理家庭成员
  - 设置 / 取消家庭管理员
  - 刷新家庭邀请码
  - 管理家庭菜品
  - 创建和管理订单
- `admin`
  - 管理普通成员
  - 刷新家庭邀请码
  - 管理家庭菜品
  - 创建和管理订单
- `member`
  - 浏览本家庭菜单
  - 加入订单并点菜
  - 查看自己有权限访问的家庭与订单信息

## 五、家庭机制

### 家庭创建与加入

- 新用户注册成功后，必须先完成以下二选一：
  - 创建家庭
  - 输入邀请码加入家庭
- 用户未归属任何家庭时，不进入主应用壳层
- 家庭邀请码由 `families.join_code` 表示
- 家庭邀请码支持刷新，刷新后旧码失效

### 家庭生命周期

- 用户退出家庭或被移出家庭时，保留历史记录，不做硬删
- 失去家庭后续访问权限，但历史订单和操作记录仍保留数据库层追踪
- v1 不提供家庭自助解散，只允许平台侧人工处理

## 六、订单机制

### 订单归属

- 每个订单必须属于一个家庭
- 创建订单者必须是该家庭活跃成员
- v1 保留约束：同一登录用户同一时间只能在一个活跃订单中

### 订单创建与加入

- 家庭成员在家庭上下文中创建订单
- 订单分享链接格式：`/app/join/{share_token}`
- 分享链接只用于加入订单，不用于加入家庭

### 订单状态流转

`ordering -> placed -> finished`

- `ordering`
  - 可加菜
  - 可删除自己加的菜
- `placed`
  - 已触发下单
  - 仍可继续加菜，但会进入新轮次
- `finished`
  - 订单结束
  - 家庭成员保留历史可见性
  - 访客失去访问入口

### 追加下单

- 继续加菜时写入 `order_round`
- `orders.current_round` 表示当前轮次
- 采购清单高亮最新轮次新增食材

## 七、访客机制

- 访客通过订单分享链接加入订单，不进入家庭
- 访客只存在于 `order_members`
- 访客不写入 `profiles`、`family_members`
- 访客在订单结束后默认失去该订单访问能力
- v1 中访客相关写操作应走 RPC / Edge Function，不开放宽松裸表写入

## 八、菜品与采购清单

### 菜品管理

- 菜品属于家庭
- 仅 `owner` / `admin` 可添加、编辑、删除或归档菜品
- 菜品字段：`name`、`category`、`image_url`、`ingredients`
- 分类仍由 `dishes.category` 动态生成，无独立分类表
- 建议图片路径按家庭维度组织，例如：
  - `families/{family_id}/dishes/{dish_id}/cover.jpg`

### 菜品状态

菜品状态属于 `order_items`，与订单状态解耦：

`waiting -> cooking -> done`

- 状态由家庭 `owner/admin` 更新
- 管理员可结束订单，不要求所有菜品先到 `done`

### 采购清单

- 不独立存表，基于订单动态聚合
- 汇总订单内全部菜品的食材
- 相同食材合并计量
- 高亮最新 `order_round` 新增条目

## 九、核心数据模型

### 表

- `profiles`
  - 用户基础档案
- `families`
  - 家庭租户
- `family_members`
  - 家庭成员与角色
- `dishes`
  - 家庭菜单
- `orders`
  - 家庭订单
- `order_members`
  - 订单参与者，兼容家庭成员与访客
- `order_items`
  - 订单中的菜品项

### 枚举

- `family_role`: `owner | admin | member`
- `family_member_status`: `active | removed`
- `order_status`: `ordering | placed | finished`
- `item_status`: `waiting | cooking | done`
- `order_member_type`: `family_member | guest`

详细设计见 [docs/family_v1_design.md](docs/family_v1_design.md)。

## 十、技术栈

- 前端：Flutter（iOS + Android）
- 后端：Supabase
  - 数据库：PostgreSQL
  - 认证：Supabase Auth（username + password）
  - 存储：Supabase Storage（菜品图片）
  - 实时同步：Supabase Realtime
- 路由：GoRouter
- 状态管理：Riverpod

## 十一、Flutter 项目结构

```text
lib/
├── core/
│   ├── supabase/
│   ├── router/
│   ├── theme/
│   └── utils/
├── features/
│   ├── auth/
│   ├── family/
│   ├── menu/
│   ├── order/
│   ├── join/
│   └── setting/
└── shared/
    ├── widgets/
    └── models/
```

建议模型文件至少包含：

- `profile.dart`
- `family.dart`
- `family_member.dart`
- `dish.dart`
- `order.dart`
- `order_member.dart`
- `order_item.dart`

## 十二、开发顺序

### Phase 0 — Tenant Foundation

目标：冻结多家庭规则并输出可执行规格。

- 确认家庭级角色模型
- 确认访客生命周期
- 确认家庭邀请码与订单分享链接策略
- 输出 Family 版 ER 图
- 输出可执行 SQL 草案
- 输出 RLS 矩阵

### Phase 1 — Backend Foundation

目标：建立多家庭数据库底座。

- 执行 `database.sql`
- 创建 7 张核心表
- 建立索引、trigger、helper function、RPC
- 启用 RLS
- 配置 Storage bucket
- 开启 Realtime

### Phase 2 — Auth & Onboarding

目标：完成注册 / 登录 / 入家闭环。

- 注册页
- 登录页
- `profiles` 初始化
- onboarding
  - 创建家庭
  - 输入邀请码加入家庭
- 家庭上下文 provider

### Phase 3 — Family Context & Shell

- 主应用壳层
- 当前家庭切换
- 空家庭 / 无订单状态处理

### Phase 4 — Menu

- 家庭菜单查询
- 分类筛选
- 管理员菜品 CRUD
- 图片上传

### Phase 5 — Order Core

- 创建订单
- 加入订单
- 点菜 / 删菜
- 订单状态流转
- 菜品制作状态更新

### Phase 6 — Guest Join & Sharing

- 分享链接
- 二维码展示
- 访客加入订单
- 受控 guest flow

### Phase 7 — Shopping List & Realtime

- 食材聚合
- 当前轮次高亮
- Realtime 订阅订单与菜品状态

### Phase 8 — Setting & History

- 个人信息
- 家庭成员管理
- 历史订单
- 错误状态与空状态收尾

## 十三、Phase 0-2 验收重点

### Phase 0

- 不再存在未收敛的租户边界问题
- 不再使用“全局管理员承载业务权限”
- 数据模型、RLS、访客规则形成单一事实源

### Phase 1

- `database.sql` 可直接执行成功
- 家庭成员只能访问本家庭数据
- 非家庭成员无法读取他人家庭菜单与订单
- 活跃订单唯一约束由 trigger / RPC 保证

### Phase 2

- 可注册、登录、登出
- 未入家的用户不会进入主应用
- 可创建家庭并成为 `owner`
- 可通过邀请码加入家庭

## 十四、Phase 1-2 实施指南

### Step 1：阅读设计文档

先阅读：

- [docs/family_v1_design.md](docs/family_v1_design.md)
- [database.sql](database.sql)
- [datamodel.dart](datamodel.dart)

### Step 2：创建 Supabase 项目

1. 登录 Supabase
2. 创建新项目
3. 记录以下信息：
   - Project URL
   - anon public key

### Step 3：执行数据库脚本

1. 打开 Supabase SQL Editor
2. 复制 [database.sql](database.sql) 全部内容
3. 执行脚本

执行后应能看到以下核心表：

- `profiles`
- `families`
- `family_members`
- `dishes`
- `orders`
- `order_members`
- `order_items`

### Step 4：验证 RPC 与 RLS

重点验证：

- 已登录用户只能读到同家庭资料与菜单
- 通过 `create_family_with_owner()` 能创建家庭并自动写入 owner
- 通过 `join_family_by_code()` 能加入家庭
- 通过 `create_order_for_family()` 能创建订单并自动入单
- 活跃订单唯一约束生效

### Step 5：配置 Storage

建议：

- bucket 名称：`dishes`
- 对象路径按家庭维度组织
- 上传权限仅给家庭 `owner/admin`

Storage 细粒度策略应在图片上传能力落地时一并实现，避免先写出与家庭边界不一致的宽松策略。

### Step 6：开启 Realtime

至少开启：

- `orders`
- `order_items`

如后续家庭成员页需要实时变化，可再评估是否订阅 `family_members`。

### Step 7：开始 Flutter Phase 1-2

优先完成：

- Supabase 初始化
- 路由与鉴权重定向
- shared models
- auth state
- family context provider
- onboarding 流程

## 十五、v1 明确不做

- 邮箱 / 第三方登录
- 找回密码
- 家庭自助解散
- 跨家庭聚合视图
- 复杂邀请审批流
- 访客订单结束后历史回看
- 多语言
- 商业化功能
