# UI Content

## 1. 文档目标

这份文档合并原有页面状态定义与界面文案，作为 v1 UI 内容层的单一事实源。

本文件解决两件事：

- 每个页面有哪些状态
- 每个状态下显示什么文案

原则：

- 简短
- 直接
- 优先告诉用户下一步动作
- 不暴露后端实现细节

## 2. 通用状态规则

### 2.1 Loading

- 首次进入页面优先使用 skeleton
- 短时局部操作使用按钮 loading 或局部 spinner
- 不使用整页无限转圈替代结构化 loading

### 2.2 Empty

- 必须说明为什么现在是空的
- 必须提供下一步动作或明确说明等待谁操作
- 统一使用 `EmptyState`

### 2.3 Error

- 只展示用户可理解的错误
- 默认带重试
- 不直接显示原始 SQL 或 Supabase 报错

### 2.4 Permission Limited

- 优先隐藏不该看见的操作
- 若用户进入受限页面，展示解释和返回路径

### 2.5 Offline / Retry

- v1 不做完整离线模式
- 网络失败统一落到可重试 error state

## 3. 全局按钮与通用文案

### 3.1 Auth

- 登录：`登录`
- 注册：`注册`
- 去注册：`去注册`
- 去登录：`去登录`

### 3.2 Onboarding

- 创建家庭：`创建家庭`
- 加入家庭：`加入家庭`
- 确认加入：`确认加入`

### 3.3 Menu

- 新增菜品：`新增菜品`
- 编辑菜品：`编辑菜品`
- 保存菜品：`保存`
- 加入订单：`加入订单`
- 加一道：`加一道`

### 3.4 Orders

- 创建订单：`创建订单`
- 分享订单：`分享订单`
- 查看采购清单：`采购清单`
- 确认下单：`确认下单`
- 结束订单：`结束订单`

### 3.5 Member Management

- 设为管理员：`设为管理员`
- 取消管理员：`取消管理员`
- 移除成员：`移除成员`

### 3.6 General

- 重试：`重试`
- 取消：`取消`
- 确认：`确认`
- 删除：`删除`
- 完成：`完成`
- 返回：`返回`
- 退出登录：`退出登录`
- 关闭：`关闭`

## 4. 页面内容规范

## 4.1 `login_page`

状态：

- loading
  - 点击登录后按钮进入 loading
- success
  - 已登录则跳转 onboarding 或 shell
- error
  - 用户名或密码错误

文案：

- error.invalidCredential：`用户名或密码不正确`
- error.network：`网络连接失败，请稍后重试`

## 4.2 `register_page`

状态：

- loading
  - 点击注册后按钮 loading
- success
  - 注册成功跳 onboarding
- error
  - 用户名已存在
  - 注册失败

文案：

- error.usernameExists：`这个用户名已经被使用`
- error.default：`注册失败，请稍后再试`

## 4.3 `onboarding_choice_page`

状态：

- success
  - 正常展示创建或加入家庭两入口
- error
  - 拉取当前用户状态失败

文案：

- helper.createFamily：`创建家庭后，你会成为这个家庭的 owner。`
- helper.joinFamily：`如果是受邀加入，请输入家庭邀请码。`

## 4.4 `create_family_page`

状态：

- editing
  - 默认输入态
- submitting
  - 提交创建
- success
  - 成功进入 shell
- error
  - 家庭创建失败

文案：

- error.default：`创建家庭失败，请稍后重试`

## 4.5 `join_family_page`

状态：

- editing
  - 默认输入邀请码
- submitting
  - 正在校验 join code
- success
  - 成功进入 shell
- error
  - 邀请码无效
  - 邀请码失效
  - 已经在家庭中

文案：

- error.invalidCode：`邀请码无效，请检查后重试`
- error.expiredCode：`邀请码已失效，请向管理员获取新邀请码`
- error.default：`加入家庭失败，请稍后重试`

## 4.6 `menu_page`

状态：

- loading
  - 首次加载菜品和分类
- success
  - 有菜品列表
- empty
  - 当前家庭还没有菜品
- empty search
  - 有菜品但搜索结果为空
- permission limited
  - member 不显示管理入口
- error
  - 拉取菜品失败

文案：

- empty.title：`还没有菜品`
- empty.description：`先把常做的菜加进菜单，点菜时会方便很多。`
- empty.adminAction：`新增菜品`
- empty.memberAction：`稍后再来看看`
- emptySearch.title：`没有找到相关菜品`
- emptySearch.description：`试试换个关键词，或者切换分类。`
- emptySearch.action：`清空搜索`
- error.default：`菜品加载失败，请稍后重试`
- error.noPermission：`你没有管理菜品的权限`

## 4.7 `dish_form_page`

状态：

- create mode
- edit mode
- uploading
- saving
- success
- error

文案：

- success.saved：`已保存`
- error.upload：`图片上传失败，请重新选择`
- error.save：`菜品保存失败，请稍后重试`

确认弹窗：

- delete.title：`删除这道菜？`
- delete.message：`删除后不会影响历史订单，但这道菜不会再出现在菜单里。`
- delete.confirm：`删除`
- delete.cancel：`取消`

## 4.8 `orders_page`

状态：

- loading
  - 拉取当前家庭订单摘要
- empty
  - 没有活跃订单
- success ordering
  - 当前订单可继续点菜
- success placed
  - 已下单，可继续追加轮次
- permission limited
  - member 看不到创建订单和推进状态按钮
- error
  - 拉取订单失败

文案：

- empty.title：`当前没有进行中的订单`
- empty.description：`创建一个订单后，大家就可以一起点菜了。`
- empty.adminAction：`创建订单`
- empty.memberAction：`等待管理员创建`
- error.default：`订单加载失败，请稍后重试`
- helper.roundRule：`已下单后新增菜品会自动进入下一轮。`
- helper.shoppingList：`采购清单会自动汇总订单里的全部食材。`

确认弹窗：

- place.title：`确认本轮下单？`
- place.message：`下单后新增菜品会进入下一轮。`
- place.confirm：`确认下单`
- place.cancel：`取消`
- finish.title：`结束当前订单？`
- finish.message：`结束后该订单将进入历史记录，不能再继续点菜。`
- finish.confirm：`结束订单`
- finish.cancel：`取消`

Toast：

- success.created：`订单已创建`
- success.copiedShareLink：`分享链接已复制`

## 4.9 `order_detail_page`

状态：

- loading
  - 拉取订单详情和 order items
- success member joined
  - 已加入订单，可加菜
- success member not joined
  - 家庭成员未加入，展示加入入口
- success placed
  - 进入追加轮次状态
- success finished
  - 只读历史态
- empty
  - 当前订单暂无菜品
- permission limited
  - member 不显示制作状态控制
- error
  - token 无效
  - 订单不存在
  - 无权限访问

文案：

- empty.title：`还没人点菜`
- empty.description：`从菜单里选几道菜，订单就会出现在这里。`
- empty.action：`去点菜`
- error.invalidToken：`分享链接无效`
- error.finished：`订单已结束，无法继续加入`
- error.conflictActiveOrder：`你当前已经在另一个进行中的订单里`
- error.noPermission：`你没有查看该页面的权限`
- error.default：`订单加载失败，请稍后重试`

Toast：

- success.joined：`已加入订单`

## 4.10 `join_order_page`

状态：

- loading
  - 校验 share token
- success eligible
  - 当前用户可加入订单
- success
  - 进入订单详情
- error
  - 分享链接无效
  - 订单已结束
  - 用户已在另一个活跃订单中
  - 当前用户不属于该家庭

文案：

- error.invalidToken：`分享链接无效`
- error.finished：`订单已结束，无法继续加入`
- error.conflictActiveOrder：`你当前已经在另一个进行中的订单里`
- error.notFamilyMember：`你不属于这个家庭，无法加入该订单`

## 4.11 `shopping_list_sheet`

状态：

- loading
  - 聚合食材中
- success
  - 展示聚合列表
- empty
  - 当前订单还没有食材
- error
  - 聚合失败

文案：

- empty.title：`还没有可汇总的食材`
- empty.description：`等有人点菜后，这里会自动生成采购清单。`
- empty.action：`关闭`
- error.default：`采购清单加载失败，请稍后重试`

## 4.12 `settings_page`

状态：

- loading
- success
- permission limited
- error

文案：

- action.logout：`退出登录`

确认弹窗：

- logout.title：`退出当前账号？`
- logout.message：`退出后需要重新登录才能继续使用。`
- logout.confirm：`退出登录`
- logout.cancel：`取消`

## 4.13 `family_members_page`

状态：

- loading
- success
- permission limited
- error

文案：

- error.noPermission：`你没有查看该页面的权限`
- error.default：`成员加载失败，请稍后重试`

确认弹窗：

- remove.title：`移除这个成员？`
- remove.message：`被移除后，对方将失去该家庭的后续访问权限。`
- remove.confirm：`移除成员`
- remove.cancel：`取消`

Toast：

- success.removed：`成员已移除`
- success.roleUpdated：`角色已更新`

## 4.14 `order_history_page`

状态：

- loading
- success
- empty
- error

文案：

- empty.title：`还没有历史订单`
- empty.description：`完成过的订单会显示在这里。`
- empty.action：`返回设置`
- error.default：`历史订单加载失败，请稍后重试`

## 4.15 `profile_page`

状态：

- loading
- success
- saving
- error

文案：

- error.default：`保存失败，请稍后重试`

## 5. 命名规范

统一使用：

- `家庭`
- `订单`
- `菜品`
- `采购清单`
- `成员`
- `管理员`

不使用：

- `房间`
- `群组`
- `菜单项`
- `房主`
