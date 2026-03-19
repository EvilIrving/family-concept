# UI Architecture

## 1. 文档目标

这份文档用于冻结 v1 的页面树、路由层级、导航结构和页面责任边界。

目标：

- 明确哪些页面存在
- 明确哪些页面是 full page
- 明确哪些入口使用 sheet
- 明确页面之间的跳转关系
- 避免开发过程中不断新增临时页面

## 2. 一级信息架构

v1 采用 5 层 UI 结构：

- Auth
- Onboarding
- App Shell
- Detail / Flow
- Overlay

说明：

- Auth 解决登录和注册
- Onboarding 解决用户首次入家
- App Shell 是主应用的底部导航容器
- Detail / Flow 是从主导航进入的完整页面
- Overlay 用于轻量操作和补充信息

## 3. 页面树

```text
Auth
├── login_page
└── register_page

Onboarding
└── onboarding_choice_page

App Shell
├── menu_page
├── orders_page
└── settings_page

Detail / Flow
├── dish_form_page
├── order_detail_page
├── join_order_page
├── empty_family_page
└── no_active_order_page

Overlay
├── dish_detail_sheet
├── shopping_list_sheet
├── family_switcher_sheet
├── profile_sheet
├── family_members_sheet
├── order_history_sheet
└── confirm_dialog
```

## 4. 路由建议

建议使用 GoRouter，路由命名保持业务清晰，不用 UI 导向命名。

```text
/login
/register
/onboarding
/app/menu
/app/orders
/app/settings
/app/menu/dish/new
/app/menu/dish/:dishId/edit
/app/orders/:orderId
/app/join/:shareToken
/app/settings/profile
/app/settings/family-members
/app/settings/order-history
```

约定：

- 底部导航页全部挂在 `/app/*`
- 订单分享入口使用 `/app/join/:shareToken`
- sheet 不单独做浏览器式深链接，除历史兼容路由外不再新增次级设置页入口
- 需要分享和恢复状态的内容，才做独立路由

## 5. Shell 结构

### 5.1 底部导航

v1 固定三项：

- Menu
- Orders
- Setting

不增加：

- 单独的 Home
- 单独的 Shopping List tab
- 单独的 History tab

原因：

- 当前核心任务是菜单、订单、设置三块
- Shopping List 依附当前订单，适合 sheet
- History 属于设置下的次级页面

### 5.2 App Shell Header

Shell 内的页面头部统一包含：

- 当前家庭名称
- 家庭切换入口
- 右侧上下文操作区

建议：

- `menu_page` 右上角是菜品管理入口
- `orders_page` 右上角保留家庭切换入口
- `settings_page` 右上角保留家庭切换入口
- 页面内容区不再重复渲染家庭切换卡片

## 6. 页面责任边界

### 6.1 `login_page`

职责：

- 邮箱登录
- 跳转注册
- 展示基础错误提示

不负责：

- 家庭选择
- 忘记密码
- 复杂账号恢复

### 6.2 `register_page`

职责：

- 在单页内完成用户注册
- 默认输入邀请码加入家庭
- 低频展开“创建家庭”
- 成功后直接进入主应用

不负责：

- 纯注册不归属家庭

### 6.3 `onboarding_choice_page`

职责：

- 为已登录但未入家的用户提供兜底家庭归属表单
- 继续采用“邀请码优先，创建家庭低频展开”的单模块交互

### 6.4 `menu_page`

职责：

- 浏览家庭菜品
- 搜索和分类筛选
- 双列卡片直接加减菜
- 点击菜品图片查看详情 sheet
- 管理员查看新增/编辑入口

不负责：

- 直接承载大表单编辑

### 6.5 `dish_form_page`

职责：

- 新增菜品
- 编辑菜品
- 上传图片
- 编辑食材

说明：

- 这是完整表单页面，不建议使用 sheet

### 6.6 `orders_page`

职责：

- 直接展示当前家庭当前订单详情
- 无订单时提供创建订单入口
- 展示订单状态、按轮分组的菜品项与管理操作

### 6.7 `order_detail_page`

职责：

- 承载独立路由下的订单详情
- 复用 Orders tab 的详情主体
- 以渐进式披露方式更新菜品制作状态
- 触发下单和结束订单
- 下单和结束订单都使用按钮二次点击确认，交互与退出登录一致
- 结束订单以全宽、更紧凑的危险按钮呈现，作为页面底部的主要破坏性动作

### 6.8 `join_order_page`

职责：

- 通过分享 token 加入订单
- 校验当前用户属于该订单家庭
- 承接链接失效和订单结束态

### 6.9 `shopping_list_sheet`

职责：

- 按轮次展示当前订单的食材聚合
- 高亮最新轮次新增食材

### 6.10 `settings_page`

职责：

- 展示当前账号与家庭信息
- 打开个人资料 sheet
- 打开成员管理 sheet
- 打开历史订单 sheet
- 处理退出家庭与退出登录

说明：

- 属于订单上下文的补充视图，不独立做一级页面

### 6.12 `settings_page`

职责：

- 个人设置入口
- 家庭信息入口
- 成员管理入口
- 历史订单入口
- 退出登录

### 6.13 `family_members_page`

职责：

- 查看成员列表
- owner/admin 管理成员
- owner 调整 admin
- owner/admin 移除 member

### 6.14 `order_history_page`

职责：

- 展示已结束订单
- 支持按时间倒序
- 可点击进入历史详情

## 7. 页面与 Overlay 边界

以下场景使用 full page：

- 登录
- 注册
- 创建家庭
- 加入家庭
- 菜品新增/编辑
- 订单详情
- 家庭成员管理
- 历史订单

以下场景使用 sheet：

- 菜品详情预览
- 创建订单
- 家庭切换
- 购物清单
- 分享订单

以下场景使用 dialog：

- 删除菜品
- 移除成员
- 退出家庭
- 登出

以下场景使用按钮二次点击确认：

- 结束订单

## 8. 返回与跳转规则

统一规则：

- Auth 页面之间使用正常 push/pop
- Onboarding 成功后 replace 到 `/app/menu`
- Shell tab 切换不保留多层返回栈
- 从 Shell 进入 detail page 使用 push
- sheet 关闭返回来源页面，不改变 tab
- destructive action 完成后关闭 dialog 并刷新当前页

## 9. 权限驱动的导航差异

### 9.1 `owner`

可见入口：

- 菜品管理
- 创建订单
- 推进订单状态
- 家庭成员管理
- 设置或取消 admin
- 刷新家庭邀请码

### 9.2 `admin`

可见入口：

- 菜品管理
- 创建订单
- 推进订单状态
- 移除普通成员
- 刷新家庭邀请码

不可见入口：

- 设置或取消 admin

### 9.3 `member`

可见入口：

- 浏览菜单
- 加入订单
- 点菜
- 查看历史订单

不可见入口：

- 菜品编辑
- 成员管理
- 订单状态推进

## 10. 开发建议

建议实现顺序：

1. 先搭路由壳层和鉴权重定向
2. 再实现 onboarding
3. 再实现 Shell 三个 tab 的静态骨架
4. 再补 detail page
5. 最后实现各类 sheet 和 dialog

这个顺序可以最早验证：

- 路由结构是否合理
- 页面边界是否清晰
- 组件抽象是否足够支撑全局
