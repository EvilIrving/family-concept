# 私厨点菜 App — Product Requirements Document

# Version: 1.0.0

## 一、产品定位

面向私厨 / 家庭 / 小型聚餐场景的点菜工具。
核心场景：厨师（管理员）创建菜单，食客扫码加入订单、自主点菜，厨师驱动制作流程。
非目标：不是菜谱工具、不是家庭管理系统、不是对外商业餐饮系统。

## 二、核心抽象

User → Order → Dish

订单是一个可分享的协作容器。
用户通过创建或扫码加入同一个订单，协作完成点菜。

## 三、用户与角色

### 账号体系

- 登录方式：username + password（username 全局唯一）
- 用户信息：username、avatar、account_id（自动生成）
- 无邮箱、无第三方登录
- 风险说明：忘记 username/password 无法找回，v1 有意接受此限制

### 角色定义

- 普通用户：加入订单、点菜、删除自己未下单的菜品
- 管理员：在普通用户基础上，额外拥有菜品管理、订单状态管理、用户权限管理能力
- 管理员是全局角色，不限定于某个订单
- 初始管理员手动在数据库设置，后续管理员由现有管理员在 Setting → 管理用户 中授权
- 管理员也可以作为普通用户下单点菜

## 四、页面结构

### 1. 菜单页（Menu）

- 浏览全部菜品
- 按 category 筛选（动态生成，无菜的分类自动消失）
- 点菜加入当前订单
- 管理模式（管理员专用）：添加 / 编辑 / 删除菜品

### 2. 订单页（Orders）

- 展示当前活跃订单
- 菜品列表，含每道菜的制作状态
- 下单按钮（用户触发）
- 每道菜可查看对应食材（bottom sheet）
- 采购清单入口（bottom sheet，汇总全部食材，高亮当前轮次新增内容）
- 管理员可更新单道菜状态（等待中 → 制作中 → 制作完成）
- 管理员可直接结束订单

### 3. 设置页（Setting）

- 个人信息
- 管理用户（管理员专用）：查看用户列表、设置 / 取消管理员
- 历史订单：查看所有已结束的订单

## 五、订单机制

### 订单创建与加入

- 首次进入且无活跃订单 → 自动创建新订单
- 扫码 / 点击分享链接 → 加入对应订单
- 同一链接 / 二维码 = 同一订单
- 一个用户同一时间只能存在于一个活跃订单（数据库层约束）

### 订单分享

- 每个订单持有一个高随机性 share_token
- 分享链接格式：/app/join/{token}
- 未登录用户访问链接 → 先登录 → 自动加入订单

### 订单状态流转

点单中 → 已下单 → 已结束

- 点单中：可自由加菜、删除自己的菜
- 已下单：由食客触发；仍可继续加菜（标记新轮次）；不可撤销已有菜品
- 已结束：由管理员触发；禁止任何操作

### 追加下单

- 已下单后继续加菜，记录 order_round（整数，第几轮下单）
- 采购清单中高亮最新轮次新增的食材

## 六、菜品状态

状态属于 order_item（菜品级），与订单状态解耦。

等待中 → 制作中 → 制作完成

- 状态由管理员手动更新
- 管理员也可跳过中间状态直接结束订单

## 七、采购清单

- 不独立存表，基于订单动态聚合
- 汇总订单内所有菜品的食材，相同食材合并计量
- 在订单页以 bottom sheet 展示
- 高亮当前最新 order_round 新增的食材条目

## 八、菜品管理

- 无独立后台
- 管理员在菜单页开启「管理模式」后操作
- 菜品字段：名称、分类、图片、食材列表
- 分类由 dishes.category 动态生成，无独立分类表
- 图片存储于 Supabase Storage

## 九、技术栈

- 前端：Flutter（iOS + Android）
- 后端：Supabase
  - 数据库：PostgreSQL
  - 认证：Supabase Auth（自定义 username 登录）
  - 存储：Supabase Storage（菜品图片）
  - 实时同步：Supabase Realtime（订单状态、菜品状态同步）

## 十、v1 明确不做

- 邮箱 / 第三方登录
- 账号找回
- 菜品评论 / 评分
- 多语言
- 商业化相关功能

## Flutter 项目结构

lib/
├── main.dart
├── app.dart                        # MaterialApp、路由、主题配置
│
├── core/
│   ├── supabase/
│   │   ├── supabase_client.dart    # Supabase 初始化单例
│   │   └── realtime_manager.dart  # 订阅管理（订单/菜品状态）
│   ├── router/
│   │   └── app_router.dart        # GoRouter 路由定义（含 /join/:token）
│   ├── theme/
│   │   └── app_theme.dart         # 颜色、字体、组件主题
│   └── utils/
│       ├── ingredient_aggregator.dart  # 食材聚合逻辑（采购清单计算）
│       └── share_helper.dart          # 生成分享链接/二维码
│
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   └── auth_repository.dart       # 登录、注册、登出
│   │   ├── presentation/
│   │   │   ├── login_screen.dart
│   │   │   └── register_screen.dart
│   │   └── providers/
│   │       └── auth_provider.dart         # 当前用户状态
│
│   ├── menu/
│   │   ├── data/
│   │   │   └── dish_repository.dart       # CRUD dishes
│   │   ├── presentation/
│   │   │   ├── menu_screen.dart           # 主页面
│   │   │   ├── components/
│   │   │   │   ├── dish_card.dart
│   │   │   │   ├── category_filter_bar.dart
│   │   │   │   └── admin_dish_form.dart   # 添加/编辑菜品表单
│   │   └── providers/
│   │       └── dish_provider.dart
│
│   ├── order/
│   │   ├── data/
│   │   │   ├── order_repository.dart      # 订单 CRUD、状态流转
│   │   │   └── order_item_repository.dart # 菜品项 CRUD、状态更新
│   │   ├── presentation/
│   │   │   ├── order_screen.dart          # 主页面
│   │   │   ├── components/
│   │   │   │   ├── order_item_tile.dart
│   │   │   │   ├── item_status_badge.dart
│   │   │   │   ├── shopping_list_sheet.dart    # 采购清单 bottom sheet
│   │   │   │   └── place_order_button.dart
│   │   └── providers/
│   │       ├── order_provider.dart
│   │       └── shopping_list_provider.dart     # 食材聚合 + 高亮逻辑
│
│   ├── join/
│   │   └── presentation/
│   │       └── join_screen.dart           # 扫码/链接进入时的中转页
│
│   └── setting/
│       ├── data/
│       │   └── user_repository.dart       # 查询用户、设置 is_admin
│       ├── presentation/
│       │   ├── setting_screen.dart        # 设置主页面
│       │   ├── manage_users_screen.dart   # 管理员专用
│       │   └── history_orders_screen.dart
│       └── providers/
│           └── user_management_provider.dart
│
└── shared/
    ├── widgets/
    │   ├── app_avatar.dart
    │   ├── status_chip.dart
    │   └── empty_state.dart
    └── models/                            # Dart 数据类，对应数据库表
        ├── profile.dart
        ├── dish.dart
        ├── order.dart
        ├── order_member.dart
        └── order_item.dart

## 开发顺序

Phase 1 — 地基（无 UI 可验证）

  1. Supabase 项目初始化
     - 执行数据库 DDL（建表、枚举、trigger、RLS）
     - 配置 Storage bucket（dishes/images）
     - 开启 Realtime（orders、order_items 两张表）

  2. Flutter 基础配置
     - 接入 Supabase Flutter SDK
     - 配置 GoRouter（含未登录重定向、/join/:token 路由）
     - 建立 shared/models（fromJson / toJson）
     - 建立 app_theme

Phase 2 — 认证
  3. 注册页（username + password → 写入 profiles）
  4. 登录页
  5. auth_provider（持久化登录状态）

- 验收：可注册、登录、登出，profiles 表数据正确

---

## Phase 1-2 详细操作指南

### Step 1: 创建 Supabase 项目

1. 打开 https://supabase.com 并登录（没有账号先注册）
2. 点击 "New Project"
3. 填写项目信息：
   - Name: `family-menu`（或你喜欢的名称）
   - Database Password: 设置一个强密码（记下来！）
   - Region: 选择离你最近的区域
4. 点击 "Create new project"，等待 2-3 分钟

### Step 2: 执行数据库 DDL

1. 在 Supabase 控制台左侧菜单，点击 "SQL Editor"
2. 点击 "New query"
3. 复制 `database.sql` 文件的全部内容，粘贴到编辑器
4. 点击 "Run" 执行
5. 如果看到绿色成功提示，表示数据库表已创建完成

**验证方法：**
- 点击左侧 "Table Editor"
- 应该能看到 5 张表：profiles, dishes, orders, order_members, order_items

### Step 3: 配置 Storage Bucket

1. 点击左侧菜单 "Storage"
2. 点击 "New bucket"
3. 填写：
   - Name: `dishes`
   - Public bucket: 打开（开关变绿）
4. 点击 "Create bucket"

**设置 Storage 策略（允许上传图片）：**

1. 点击刚创建的 `dishes` bucket
2. 点击上方 "Policies" 标签
3. 点击 "New policy" → "For full customization"
4. 创建以下策略：

**策略 1 - 允许所有人查看图片：**
- Policy name: `Public read access`
- Allowed operation: SELECT
- Target roles: 选择 `authenticated`
- Policy definition: `true`
- 点击 "Review" → "Save policy"

**策略 2 - 允许管理员上传图片：**
- 点击 "New policy" → "For full customization"
- Policy name: `Admin upload`
- Allowed operation: INSERT
- Target roles: 选择 `authenticated`
- Policy definition: `(SELECT is_admin FROM profiles WHERE id = auth.uid()) = true`
- 点击 "Review" → "Save policy"

### Step 4: 开启 Realtime

1. 点击左侧菜单 "Database"
2. 点击子菜单 "Replication"
3. 找到 "supabase_realtime" 这一行
4. 点击 "0 tables" 进入配置
5. 找到并勾选以下两张表：
   - `orders`
   - `order_items`
6. 点击 "Save"

### Step 5: 获取 Supabase 密钥

1. 点击左侧菜单 "Project Settings"（齿轮图标）
2. 点击 "API"
3. 记录以下两个值（后面 Flutter 配置需要用）：
   - **Project URL**: 形如 `https://xxxxx.supabase.co`
   - **anon public key**: 一串很长的字符串

---

### Step 6: 创建 Flutter 项目

打开终端，执行以下命令：

```bash
# 进入你的工作目录
cd /Users/cain/Documents/code/flutter-family-concept

# 创建 Flutter 项目
flutter create --org com.yourname family_menu

# 进入项目目录
cd family_menu
```

### Step 7: 添加依赖

编辑 `family_menu/pubspec.yaml`，在 `dependencies:` 下添加：

```yaml
dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^2.5.0
  go_router: ^14.0.0
  flutter_riverpod: ^2.5.0
  riverpod_annotation: ^2.3.0
```

然后在终端执行：

```bash
cd family_menu
flutter pub get
```

### Step 8: 创建项目目录结构

在 `family_menu/lib/` 下创建以下文件夹：

```
lib/
├── core/
│   ├── supabase/
│   ├── router/
│   ├── theme/
│   └── utils/
├── features/
│   ├── auth/
│   │   ├── data/
│   │   ├── presentation/
│   │   └── providers/
│   ├── menu/
│   ├── order/
│   ├── join/
│   └── setting/
└── shared/
    ├── widgets/
    └── models/
```

**终端命令（可选，手动创建也可以）：**

```bash
cd family_menu/lib
mkdir -p core/supabase core/router core/theme core/utils
mkdir -p features/auth/data features/auth/presentation features/auth/providers
mkdir -p features/menu features/order features/join features/setting
mkdir -p shared/widgets shared/models
```

### Step 9: 配置 Supabase 客户端

告诉我，我会帮你创建 `lib/core/supabase/supabase_client.dart` 文件。

需要用到 Step 5 记录的：
- Project URL
- anon public key

### Step 10: 创建数据模型

告诉我，我会帮你创建 `lib/shared/models/` 下的 5 个模型文件：
- profile.dart
- dish.dart
- order.dart
- order_member.dart
- order_item.dart

### Step 11: 配置路由

告诉我，我会帮你创建 `lib/core/router/app_router.dart`。

### Step 12: 配置主题

告诉我，我会帮你创建 `lib/core/theme/app_theme.dart`。

---

### Phase 2: 认证功能

完成 Phase 1 后，告诉我，我会帮你实现：
- 注册页面
- 登录页面
- auth_provider（登录状态管理）

---

### 当前进度检查清单

- [ ] Step 1: Supabase 项目创建完成
- [ ] Step 2: 数据库 DDL 执行成功
- [ ] Step 3: Storage bucket 配置完成
- [ ] Step 4: Realtime 开启完成
- [ ] Step 5: 已记录 Project URL 和 anon key
- [ ] Step 6: Flutter 项目创建完成
- [ ] Step 7: 依赖添加完成
- [ ] Step 8: 目录结构创建完成
- [ ] Step 9: Supabase 客户端配置完成
- [ ] Step 10: 数据模型创建完成
- [ ] Step 11: 路由配置完成
- [ ] Step 12: 主题配置完成
- [ ] Phase 2: 认证功能完成

**完成一步后，回来告诉我，我会指导你下一步。**

Phase 3 — 菜单核心
  6. dish_repository（read all、按 category 过滤）
  7. menu_screen + dish_card + category_filter_bar
  8. 管理模式：admin_dish_form（添加/编辑/删除）+ 图片上传

- 验收：管理员可管理菜品，普通用户可浏览

Phase 4 — 订单核心
  9. order_repository（创建订单、加入订单、状态流转）
  10. order_item_repository（加菜、删菜、更新状态）
  11. join_screen（token 解析 → 加入订单）
  12. order_screen + order_item_tile + place_order_button

- 验收：完整点菜→下单→管理员更新制作状态→结束订单 流程跑通

Phase 5 — 采购清单
  13. ingredient_aggregator（聚合逻辑 + order_round 高亮计算）
  14. shopping_list_sheet

- 验收：食材正确合并，追加菜品后高亮新增食材

Phase 6 — 分享 + 实时同步
  15. share_helper（生成链接 + 二维码展示）
  16. realtime_manager（订阅 order_items 状态变化，驱动 UI 更新）

- 验收：多设备同时点菜，状态实时同步

Phase 7 — Setting
  17. setting_screen（设置主页面）
  18. manage_users_screen（管理员授权）
  19. history_orders_screen（已结束订单列表）

Phase 8 — 收尾
  20. 图片压缩（上传前 client 端压缩，目标 < 300KB）
  21. 错误处理 / loading 状态补全
  22. 空状态 UI（无菜品、无订单）
  23. 真机测试（iOS + Android）



