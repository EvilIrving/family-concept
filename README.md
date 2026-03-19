# 私厨点菜 App — Product Requirements Document

> 事实来源：[`docs/family_v1_design.md`](docs/family_v1_design.md)
>
> 本文件仅提供项目介绍、开发顺序与文档导航，不作为权限、数据模型和流程的最终定义。

## 一、产品定位

面向私厨 / 家庭 / 小型聚餐场景的点菜工具。

核心场景：

- 厨师或家庭成员先进入一个家庭空间
- 家庭管理员维护本家庭菜单
- 食客通过家庭上下文创建订单或加入订单
- 家庭成员围绕同一个订单协作点菜
- 厨师驱动制作流程并最终结束订单

非目标：

- 不是菜谱工具
- 不是通用家庭管理系统
- 不是对外商业餐饮系统

## 二、核心抽象

`User -> Family -> Order -> OrderItem -> Dish`

更完整的权限、租户边界、状态流转与约束，请以 [docs/family_v1_design.md](docs/family_v1_design.md) 为准。

## 三、核心设计原则

- 业务权限属于家庭成员关系，不属于全局用户
- `profiles.is_admin` 如保留，仅表示平台运维角色，不参与业务授权
- 新用户注册后必须先创建家庭或加入家庭，才能进入主应用
- 家庭邀请码与订单分享链接是两套不同机制

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
- 分享链接只用于家庭成员加入订单，不用于加入家庭

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

### 追加下单

- 继续加菜时写入 `order_round`
- `orders.current_round` 表示当前轮次
- 采购清单高亮最新轮次新增食材

## 七、菜品与采购清单

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

## 八、核心数据模型

核心表、枚举与约束见 [docs/family_v1_design.md](docs/family_v1_design.md)。

## 九、技术栈

- 前端：Flutter（iOS + Android）
- 后端：Supabase
  - 数据库：PostgreSQL
  - 认证：Supabase Auth（username + password）
  - 存储：Supabase Storage（菜品图片）
  - 实时同步：Supabase Realtime
- 路由：GoRouter
- 状态管理：Riverpod

## 十、Flutter 项目结构

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
 
 