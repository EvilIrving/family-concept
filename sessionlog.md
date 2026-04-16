## 修复菜品图片拍照/选图崩溃并重构图片预处理入口 · 2026-04-16 · Claude

相机拍照或从相册选原图时概率性 OOM crash，根因是全分辨率图（12MP，~46MB）直接进裁图页，内存里同时存在原图、归一化图、Vision 缩图三份副本。另有一个裁切坐标 bug：`crop()` 里 X 轴偏移误用了 `vpY`（Y 轴值），导致水平方向裁切位置偏移。

修复路径：

`DishImagePipeline.swift` 新增 `standardizedForCrop(jpegQuality:)`，在图片进入裁图页前做一次 JPEG 重编码，把 HEIC、Live Photo 静帧等任意格式统一转为标准位图，顺带做质量压缩，不改变像素尺寸。这是给裁图和 Vision 的稳定输入。`jpegReencoded`、`scaledDown` 提升为 `internal`，`DishPhotoCropView` 里的重复私有实现已删除，`process()` 内部的 `normalized()`（已废弃）替换为 `jpegReencoded`。

`MenuView.swift` 两处注入点（PhotosPicker onChange、相机 onCapture 回调）改为调 `standardizedForCrop()`，PhotosPicker 路径在 detached task 里执行避免阻塞主线程。

`DishPhotoCropView.swift` 修正 `crop()` 里的坐标 bug：`imageLeft - vpY` → `imageLeft - vpLeft`，`vpLeft = viewportCenter.x - vpWidth / 2`。

## iOS 端切换到账号制 · 2026-04-15 · Claude

这次把 iOS 端从旧的 `device_id + displayName + X-Device-Id` 体系完整切到账号制，与 worker 侧已落地的 `/auth/*` 接口对齐。

**模型层（Domain.swift）**：`Device` → `Account`（字段 `id`、`userName`、`nickName`、`createdAt`）；`Kitchen.ownerDeviceId` → `ownerAccountId`；`Member.deviceRefId` → `accountId`、`displayName` → `nickName`；`Dish/Order/OrderItem` 的 `*DeviceId` 字段全部改成 `*AccountId`；删除 `LoginResponse`，新增 `AuthResponse { token, account }` 和 `AuthMeResponse { account }`。

**网络层（APIClient + APIEndpoints）**：`request()` 的 `deviceId` 参数改成 `authToken`，请求头从 `X-Device-Id` 换成 `Authorization: Bearer <token>`。新增 `register`、`login`、`logout`、`fetchMe` 四个 auth 接口；`onboardingComplete` body 去掉 `device_id`，改为 `{ mode, nick_name?, invite_code?, kitchen_name? }` + Bearer 鉴权；所有业务接口（kitchens、members、dishes、orders）同步换成 `authToken` 参数；成员删除接口参数从 `deviceRefID` 改成 `accountID`；移除 `registerDevice`、`fetchDevice`、旧 `login(displayName:)`。

**AppStore**：核心状态从 `currentDevice + deviceId` 换成 `currentAccount + authToken`；UserDefaults 存储项改为 `authToken`、`accountID`、`nickName`、`lastKitchenID`，不再存 `deviceID`。新增 `bootstrap()` 启动恢复逻辑：有 token → 调 `auth/me` → 有 `lastKitchenID` 则恢复 kitchen，401 则清空本地 session。新增 `login(userName:password:inviteCode:kitchenName:)`、`register(...)`、`signOut()`、`clearSession()`；`leaveKitchen` 和成员被踢出后清空 `lastKitchenID`；onboarding 成功后写入 `lastKitchenID`；`currentMember` 匹配逻辑改为 `accountId == currentAccount?.id`。

**ContentView**：增加 `isBootstrapping` 态（显示空白页防止闪烁），加入 `.task { await store.bootstrap() }` 在启动时触发恢复流程。

**OnboardingView**：重写为单页多模式状态机。`authMode`（login/register）+ `kitchenMode`（join/create）双轴控制；未登录时展示用户名/密码表单，注册模式额外显示昵称字段，下方可选择加入/创建 kitchen；已登录但无 kitchen 时只展示 join/create 选择区；密码字段通过新增的 `AppTextField.isSecure` 参数走 `SecureField`。

**SettingsView**：成员头像、身份显示、"这是我的账号"判断全部基于 `accountId`；`removeMember` 调用改为 `accountID` 参数；底部新增"退出登录"按钮卡片。

**AppTextField**：新增 `isSecure: Bool = false` 参数，为 true 时切换为 `SecureField`。

## 账号制重构与 Cloudflare 线上落地 · 2026-04-15 10:19 · Codex

这次把 worker 的身份体系从 `device_id + display_name` 重构成真正的账号制。核心模型改成 `accounts(id, user_name, password_hash, nick_name)` 和 `sessions(account_id, token_hash, expires_at)`，所有业务表和接口也同步从 device 语义切到 account 语义：`kitchens.owner_account_id`、`members.account_id`、`dishes.created_by_account_id`、`orders.created_by_account_id`、`order_items.added_by_account_id`。`X-Device-Id` 鉴权被统一替换成 `Authorization: Bearer <token>`，新增 `POST /api/v1/auth/register`、`POST /api/v1/auth/login`、`POST /api/v1/auth/logout`、`GET /api/v1/auth/me`，原来的 `devices/register` 和 `by-device` 路由已经废弃。

数据库侧新增了 `worker/migrations/0003_accounts_auth.sql`。这条迁移会创建 `accounts`、`sessions`，再用重建表的方式把 `kitchens`、`members`、`dishes`、`orders`、`order_items` 全量迁到 account 外键，同时把旧 `devices` 数据映射到 `accounts`，最后删除 `devices` 表。为了让本地和远端 migration 链路一致，`0002_unique_display_name.sql` 需要改成幂等写法 `CREATE UNIQUE INDEX IF NOT EXISTS ...`，否则远端已经存在该索引时会卡死在 `0002`，`0003` 根本不会开始执行。

业务逻辑也一起收口了。`onboarding` 现在依赖当前登录账号，不再接收 `device_id`；如果请求里带了 `nick_name`，会先更新账号昵称，再执行加入或创建 kitchen。成员列表展示名统一来自 `accounts.nick_name`。本地验证脚本 `worker/test-local.sh` 已经改成账号制，覆盖注册、登录、`auth/me`、创建/加入 kitchen、成员权限、菜品、订单、登出失效，全链路在本地 `wrangler dev + D1 local` 下跑通。

这次线上还踩到了两个 Cloudflare 相关的坑。第一，远端 D1 migration 是否成功只取决于本地 migration 文件和 D1 migration 记录，手工在 Dashboard 执行 SQL 不会让 `wrangler d1 migrations apply --remote` 跳过那条 migration。第二，Workers 的 PBKDF2 iteration 上限是 `100000`，本地代码最初用的 `210000` 在本地可跑、线上注册会直接报 `NotSupportedError`。最终把 `worker/src/auth.ts` 里的 `PASSWORD_ITERATIONS` 固定为 `100000`，重新 deploy 后线上注册恢复正常。期间还顺手修了一个安全问题：`onboarding/complete` 一度把 `password_hash` 原样带回响应，现在已经在路由层做了脱敏，只返回 `id`、`user_name`、`nick_name`、`created_at`。

## 修复食材输入框输入法立即消失问题 · 2026-04-14 · Claude

食材输入框（"添加食材"）使用中文输入法时，每输入一个字母拼音，输入法候选框就会立即消失，无法正常组字。

根因是该输入框使用了 `UIViewRepresentable` 包装 `UITextField`。用户输入时 `textChanged` 更新 `@Binding var text`，触发 SwiftUI 重新调用 `updateUIView`，其中 `uiView.text = text` 会清除 UITextField 的 `markedText`（IME 组字状态），导致输入法被强制中断。

修复方案：删除整个 `IngredientTextField`（UIViewRepresentable，约 85 行），替换为原生 SwiftUI `TextField`。原生 TextField 内部正确处理 IME 组字，不存在此问题。空格提交和回车提交功能通过 `.onChange(of:)` 和 `.onSubmit` 保留。同时将 `import UIKit` 改为 `import SwiftUI`。

修改文件：`kitchen/kitchen/Views/MenuView.swift`

## 真机联调切换到 Cloudflare 正式域名 · 2026-04-14 10:28 · Codex

这次真机显示“网络🔗失败”，根因是 iOS 端把 API 地址写成了 `http://localhost:8787`。模拟器访问本机服务时还能工作，真机里的 `localhost` 指向手机自己，所以请求一定失败。

后续决定直接走 Cloudflare 正式后端，统一使用 `https://api.kitchen.onecat.dev`。这样真机、模拟器和后续外部测试都走同一条 HTTPS 链路，省掉局域网 IP、ATS 例外和本地穿透问题。对应修改已经落在 `kitchen/kitchen/Info.plist`、`kitchen/kitchen/Services/APIClient.swift` 和 `worker/wrangler.jsonc`。

部署时又遇到一个 Cloudflare 新规则：免费版 Durable Objects 需要用 `new_sqlite_classes` 声明迁移，旧写法 `new_classes` 会直接部署失败，报错代码是 `10097`。这个坑已经在 `worker/wrangler.jsonc` 修正，后面如果再新建 Durable Object，继续沿用 SQLite migration 写法。

README 也补上了正式部署说明，部署目标域名固定为 `api.kitchen.onecat.dev`，流程是 `pnpm d1:migrate:remote` 后再 `pnpm deploy`，部署后先验证 `/api/v1/health` 和 `/api/v1/bootstrap`。

## 修复多因素导致的 Android 应用启动失败问题

time: 2026-03-12

source: gemini-cli

topic: Android Build and Launch Debugging

tags: [bugfix, build, android, gradle]

summary:
应用在 Android 模拟器上启动失败（超时）。经过排查，发现问题由多个因素共同导致：Dart 代码层面的编译错误、静态分析警告（包括缺失依赖和废弃 API），以及最关键的本地 Java 环境配置错误。通过逐一修复这些问题，最终成功在 Android 模拟器上构建并启动了应用。

decisions:

1. **修复 Dart 编译错误:** 修正了 `lib/data/database_helper.dart` 中 `Sqflite.firstIntValue` 方法的参数类型错误。
2. **解决静态分析问题:**
    * 为项目添加了缺失的 `path` 依赖。
    * 移除了 `database_helper.dart` 中不必要的类型转换。
    * 将项目中所有已废弃的 `withOpacity()` 调用替换为推荐的 `withAlpha()`。
3. **诊断和修复构建环境:**
    * 多次尝试 `launch_app` 均超时，怀疑是 Android 构建问题。
    * 直接在 `android` 目录下运行 `./gradlew assembleDebug`，明确了错误是“找不到 Java 运行时”。
    * 运行 `flutter doctor -v` 查找到正确的 `JAVA_HOME` 路径。
    * 设置正确的 `JAVA_HOME` 环境变量后，成功执行了 Gradle 构建。
4. **成功启动:** 在解决了所有代码和环境问题后，`launch_app` 命令成功启动了应用。

reason:
* `launch_app` 工具的超时错误信息不够具体，无法直接定位到是 Dart 代码问题还是原生构建环境问题。通过使用 `analyze_files` 定位代码问题，并直接调用 `gradlew` 来获取更详细的原生构建错误日志，是解决此类复合问题的有效策略。`flutter doctor` 默认不显示 Java 路径，需要使用 `-v` 参数获取详细信息。

refs:
* `lib/data/database_helper.dart`
* `flutter doctor -v`
* `cd android && export JAVA_HOME=... && ./gradlew assembleDebug`

## 基于 display name 的登录流落地 · 2026-04-14 · Codex

这批未提交改动把首次进入流程改成了“先按名字登录，再决定加入或创建”。后端新增 `POST /api/v1/auth/login`，按 `display_name` 查找设备、活跃成员和所属私厨；命中时直接返回 `device`、`member`、`kitchen`，未命中时返回 `found: false`，由客户端继续走创建或加入分支。

数据层同时补上 display name 唯一性约束。`worker/migrations/0002_unique_display_name.sql` 新增 `devices(display_name)` 唯一索引，`worker/src/routes/devices.ts` 在注册设备时先检查重名，`worker/src/services/onboarding-service.ts` 也把 onboarding 里的设备 upsert 改成“存在则按需更新 display_name，不存在则创建”，保证名字修改和首次注册都遵守同一套唯一性规则。

iOS 端围绕这条新登录流做了完整接线。`kitchen/kitchen/Services/APIEndpoints.swift` 和 `kitchen/kitchen/Models/Domain.swift` 新增登录接口与 `LoginResponse`，`kitchen/kitchen/Stores/AppStore.swift` 新增 `login(displayName:)` 和 `loginNotFound` 状态，命中已有设备后同步更新本地 `deviceId` 与保存的名字，未命中时保留输入名字并切到后续 onboarding。`kitchen/kitchen/Views/OnboardingView.swift` 也重写成 login-first 三阶段界面：先输入名字登录，找不到名字时再展示“输入邀请码加入”或“创建私厨”两个分支。

这次还合入了 Codex review 后确认的修正。P1 继续保留“按名字登录”的方案，作为当前产品阶段的设计取舍；P2 的 stale name 问题通过 `updateDisplayName` 修复，已有设备再次 onboarding 时会更新名字；另一个 P2 的 duplicate name 风险也在设备注册和 onboarding 两条路径都补上了冲突检查。
