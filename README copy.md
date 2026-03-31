# Family Kitchen App

## 技术栈

- Flutter
- Riverpod
- GoRouter
- Supabase
  - Auth
  - PostgreSQL
  - Storage
  - Realtime

产品说明书

用户登录注册：username email password
家庭模块: 创建家庭 邀请码加入家庭 成员管理
菜单管理: 上传菜品(可能包含规格)/多规格饮品，Item 可编辑，删除。
订单模块：Customer 查看家庭菜单，选择菜品 + 规格，下单。 admin or owner 编辑订单(ordered,completed)/菜品(ready, cooking, done)状态. 订单区分 轮次(第一轮下单/第二轮下单/第三轮下单/...)
采购清单：根据订单轮次，显示需要采购的ingredients(Item的食材)
历史订单：订单list，订单菜品 详情等。
设置模块：个人资料，家庭信息，邀请码操作，成员管理，历史订单。 


## 当前功能

- 邮箱登录
- 邮箱 + 用户名 + 密码注册
- 注册页内联完成加入家庭或创建家庭
- 当前家庭切换
- 家庭菜单双列浏览、搜索、分类筛选、直接加减菜
- 菜品规格数据模型，支持饮品的杯型、温度、口味等通用规格组
- 菜品新增 / 编辑 / 规格定义 / 归档 / 图片上传
- 点菜时可通过规格选择 Sheet 选择饮品规格
- Orders 页直接展示当前订单
- 当前订单加菜、下单、结束订单、采购清单
- 设置页家庭信息、邀请码操作、个人资料 sheet、成员管理 sheet、历史订单 sheet

## 运行项目

### 必需环境变量

通过 `--dart-define` 提供：

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `APP_BASE_URL`
  - 可选，用于生成完整订单分享链接

示例：

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY \
  --dart-define=APP_BASE_URL=https://YOUR_APP_HOST
```

### Supabase 侧准备

- 先执行根目录 [`database.sql`](/Users/actor/Documents/code/flutter-family-concept/database.sql)
- 创建 Storage bucket：`dishes`
- 菜品图片路径必须为 `{family_id}/{dish_id}.jpg`
- Auth 使用真实邮箱密码登录注册；如果要注册后直接进入应用，需要关闭邮箱确认

## 常用命令

```bash
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

## 文档导航

- 设计总规格：[`docs/family_v1_design.md`](/Users/actor/Documents/code/flutter-family-concept/docs/family_v1_design.md)
- UI 架构：[`docs/ui_architecture.md`](/Users/actor/Documents/code/flutter-family-concept/docs/ui_architecture.md)
- UI 文案：[`docs/ui_content.md`](/Users/actor/Documents/code/flutter-family-concept/docs/ui_content.md)
- 组件说明：[`docs/ui_components.md`](/Users/actor/Documents/code/flutter-family-concept/docs/ui_components.md)
- 视觉主题：[`docs/ui_theme.md`](/Users/actor/Documents/code/flutter-family-concept/docs/ui_theme.md)
