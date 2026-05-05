# App Store Connect 上架填表 · 食单 · 简体中文

更新时间: 2026-05-05。字段值基于仓库静态扫描生成，含 `{待补}` 的字段提交前必须由账号主体确认。

## A. App 信息

App 名称: `APPSTORENAME - SOMEKEYWORDS` 格式（9/30）— 推断
```text
食单 - 家庭菜单
```

包内图标显示名: （2/约13）— src: kitchen/kitchen/Info.plist:8
```text
食单
```

副标题: （11/30）— 推断
```text
全家共享菜单与买菜清单
```

SKU: 内部 ID，不展示给用户 — 推断
```text
cain.kitchen.ios.1
```

Apple ID: App Store Connect 创建后自动生成
```text
{待 App Store Connect 自动生成}
```

Bundle ID: 只读核对 — src: kitchen/kitchen.xcodeproj/project.pbxproj:357
```text
cain.com.kitchen
```

隐私政策 URL: iOS 必填；当前代码内已有入口但内容需最终确认 — src: kitchen/kitchen/Views/Settings/PageView.swift:15
```text
https://evilirving.github.io/family-concept
```

主要语言: 中文商店页建议值 — 推断
```text
简体中文
```

主分类: 推荐值 — 推断
```text
美食佳饮
```

次分类: 推荐值 — 推断
```text
生活
```

分类理由: — src: README.md:3
```text
产品核心是家庭菜单、菜品维护、点餐、采购清单和做饭协作，主分类用美食佳饮，生活分类承接家庭协作场景。
```

内容版权: 主体名需账号持有人确认
```text
© 2026 {主体名}
```

许可协议: 默认推荐
```text
Apple 标准许可协议
```

年龄分级 · 总评级: — 推断
```text
4+
```

年龄分级 · 暴力、性内容、裸露、粗俗语言、烟酒毒品、恐怖、赌博、医疗信息: — src: README.md:3
```text
均无。App 是家庭菜单、点餐和采购清单工具，不包含上述内容。
```

年龄分级 · 用户生成内容或用户互动: — src: worker/CLAUDE.md:84
```text
有，轻度。菜品、图片、订单和反馈由用户创建，但仅在受邀私厨成员范围内可见，没有公开社区、公开聊天或内容发现流。
```

年龄分级 · 不受限网页访问: — src: kitchen/kitchen/Views/Settings/PageView.swift:78
```text
无。App 只有隐私政策外链，不提供通用网页浏览器。
```

年龄分级 · 未加密传输: — src: kitchen/kitchen/Info.plist:5
```text
否。默认 API 使用 HTTPS。
```

DSA / 欧盟交易者状态: 需 App Store Connect 账号主体确认
```text
{待账号主体确认}
```

标签和标记 URL: Labels and Markings URLs
```text
不适用
```

韩国可用性相关声明: 上架韩国前确认
```text
如上架韩国，需确认账号主体、客服联系方式、内容分级和内购税务信息是否满足当地要求。
```

中国大陆可用性相关声明: 上架中国大陆前确认
```text
如上架中国大陆，需确认 ICP、隐私政策、账号注销、数据出境、内购税务和内容合规要求。
```

越南可用性相关声明: 上架越南前确认
```text
如上架越南，需确认账号主体、税务信息、隐私政策和当地可用性要求。
```

## B. 当前版本 1.0

推广文本: （43/170）— 推断
```text
把家里常做菜整理成共享菜单，家人一起点菜，采购清单自动汇总。
```

描述: （447/4000）— src: README.md:3
```text
每天都在问“今天吃什么”？食单把家里的常做菜变成一份全家共享的点菜单，让想吃的人点菜，让做饭的人按单安排，少一点来回确认，多一点清楚。

为家里的菜建一份真正会用的菜单
添加菜名、分类、食材和封面图，把红烧肉、番茄炒蛋、孩子爱吃的面、周末才做的大菜都收进同一个私厨菜单。菜不是冷冰冰的菜谱库，而是你家真的会做、真的会点的那几道。

家人点菜，当前订单自动合并
每个成员从菜单里选择想吃的菜，食单会把大家的选择汇总成当前订单。做饭的人可以把每道菜推进到待做、烹饪中、已完成，其他人不用反复问“做了吗”。

买菜前自动看清要准备什么
当前订单会按食材生成采购清单，适合出门买菜前快速核对，也适合临时补货。吃完的一餐会进入历史记录，方便回看最近吃过什么，下一次就不用从零想。

适合家庭私厨的小协作
通过邀请码邀请家人加入同一个私厨，并用房主、管理员、成员权限区分管理和点餐。免费版可维护最多 10 道菜，一次性内购可扩展到 50 道菜或无限菜品。食单没有订阅，没有广告，也不接入第三方追踪 SDK。
```

关键词: （43/100）— 推断
```text
家庭菜单,备餐,买菜,点菜,今天吃什么,菜谱,食谱,购物清单,做饭,厨房,家庭协作,私厨,菜单
```

支持网址: — src: kitchen/kitchen/Views/Settings/PageView.swift:15
```text
https://evilirving.github.io/family-concept
```

营销网址: 如无官网可留空
```text
{待补或留空}
```

这个版本的新功能: 首发文案（79/4000）— 推断
```text
食单首个版本上线：支持创建家庭私厨、维护菜品菜单、通过邀请码邀请成员、一起点餐、推进当前订单、自动生成采购清单、查看历史订单，并通过一次性内购扩展菜品上限。
```

版本号: 只读核对 — src: kitchen/kitchen.xcodeproj/project.pbxproj:356
```text
1.0
```

Build: 只读核对 — src: kitchen/kitchen.xcodeproj/project.pbxproj:341
```text
1
```

版本发布设置: 推荐
```text
手动发布
```

分阶段发布: 首发不适用
```text
不启用
```

重置评分: 首发不适用
```text
不适用
```

版权: 主体名需确认
```text
© 2026 {主体名}
```

联系信息: 审核联系人
```text
姓名 {待补}；电话 {待补}；邮箱 {待补}
```

## B2. 价格与可用范围

App 价格: 推荐
```text
免费
```

可用国家或地区: 推荐
```text
全部可用
```

预订: 首发推荐
```text
不启用
```

商务与教育分发: 默认
```text
不启用
```

最低兼容版本设置: 首发不适用
```text
不适用
```

税务类别: 需主体确认
```text
{待 App Store Connect/税务主体确认}
```

## C. App 隐私

总体结论: — src: kitchen/kitchen/PrivacyInfo.xcprivacy:5
```text
不追踪用户，不接入广告 SDK 或第三方分析 SDK；收集的数据仅用于 App 功能。
```

联系信息: — 推断
```text
不收集。
```

健康与健身: — 推断
```text
不收集。
```

财务信息: — src: kitchen/kitchen/Services/PurchaseManager.swift:65
```text
不收集。付款由 App Store 处理，App 只处理 StoreKit 购买结果和权益同步。
```

位置: — 推断
```text
不收集。
```

敏感信息: — 推断
```text
不收集。
```

通讯录: — 推断
```text
不收集。
```

用户内容 · 照片或视频: — src: kitchen/kitchen/PrivacyInfo.xcprivacy:26
```text
收集，关联用户，不用于追踪，用途为 App 功能，用于菜品封面图。
```

用户内容 · 其他用户内容: — src: kitchen/kitchen/PrivacyInfo.xcprivacy:40
```text
收集，关联用户，不用于追踪，用途为 App 功能，用于菜品名称、分类、食材、厨房名和订单内容。
```

浏览历史: — 推断
```text
不收集。
```

搜索历史: — 推断
```text
不收集。
```

标识符 · 用户 ID: — src: kitchen/kitchen/PrivacyInfo.xcprivacy:54
```text
收集，关联用户，不用于追踪，用途为 App 功能，用于服务端账号识别。
```

标识符 · 设备 ID / IDFA: — src: kitchen/kitchen/PrivacyInfo.xcprivacy:5
```text
不收集。
```

购买记录: — src: kitchen/kitchen/Services/PurchaseManager.swift:72
```text
不收集为 Apple 隐私标签中的购买记录。App 接收 StoreKit 交易结果，仅用于同步当前私厨权益。
```

使用数据: — 推断
```text
不收集。
```

诊断: — 推断
```text
不收集。未发现 Crashlytics、Sentry、Bugsnag 或其他诊断 SDK。
```

其他数据类型: — src: kitchen/kitchen/PrivacyInfo.xcprivacy:68
```text
收集，关联用户，不用于追踪，用途为 App 功能，用于会话令牌等账号状态。
```

Privacy Policy URL: — src: kitchen/kitchen/Views/Settings/PageView.swift:15
```text
https://evilirving.github.io/family-concept
```

User Privacy Choices URL: 如无单独页面可留空
```text
{待补或留空}
```

账号删除与数据访问: 提交前必须补齐
```text
当前扫描只发现退出登录和隐私政策入口，未发现账号删除、数据导出或隐私选择入口。
```

## C2. App 辅助功能

Accessibility URL: 如无公开页面可留空
```text
{待补或留空}
```

辅助功能营养标签初稿: 需人工核对
```text
支持系统字体和 SwiftUI 原生控件的基础可访问性表现；关键表单、按钮、分段控件、相机和相册流程需在真机上用 VoiceOver、动态字体、深色模式、降低动态效果和对比度设置逐项核对。
```

## D. App 审核信息

联系人姓名: 
```text
{待补}
```

联系人电话:
```text
{待补}
```

联系人邮箱:
```text
{待补}
```

演示账号: 检测到登录系统 — src: worker/src/routes/auth.ts:21
```text
用户名 reviewer_demo；密码 {待补}；邀请码 {可选，待补}
```

审核备注: — src: README.md:3
```text
食单是家庭私厨菜单与点餐协作工具。内容只在创建者与受邀家庭成员之间可见，没有公开社区、公开聊天、广告或追踪。

建议审核路径：注册或登录，创建私厨，添加菜品，从菜单点菜，在订单页推进状态，查看采购清单和历史订单。

相机仅用于用户主动拍摄菜品封面，相册仅用于用户主动选择菜品图片。内购为非消耗型一次性购买，只扩展当前私厨的菜品数量上限，无订阅。
```

## E. 出口合规 / 加密

是否使用加密: — src: kitchen/kitchen/Services/APIClient.swift:47
```text
是，仅使用 HTTPS、Apple 标准 API 和 SHA-256 摘要。
```

ITSAppUsesNonExemptEncryption: 建议写入 Info.plist
```text
false
```

出口合规依据: — src: kitchen/kitchen/Models/Entitlement.swift:97
```text
URLSession 用于 HTTPS API 请求，CryptoKit.SHA256 仅用于派生 StoreKit appAccountToken，不实现自定义加密通信或专有加密算法。
```

## F. 内容版权 / 第三方内容

是否包含第三方内容: — 推断
```text
否。
```

授权说明: — src: worker/CLAUDE.md:88
```text
用户上传自己的菜品照片和家庭菜单内容；App 不内置第三方菜谱库、音乐、视频或影视素材。
```

第三方 SDK: — src: kitchen/kitchen.xcodeproj/project.pbxproj:10
```text
使用 Nuke 做图片加载与缓存；未发现广告、追踪或第三方分析 SDK。
```

## G. 广告标识符 IDFA

是否使用 IDFA: — src: kitchen/kitchen/PrivacyInfo.xcprivacy:5
```text
否。
```

用途勾选:
```text
全部不勾选。
```

依据:
```text
未发现 AppTrackingTransparency、ASIdentifierManager、GADMobileAds、AdMob 或 SKAdNetwork 配置。
```

## H. 截图与预览

iPhone 6.9 英寸截图: Apple 官方规格，2026-05-05 核对 — src: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
```text
1260×2736、1290×2796 或 1320×2868 竖屏；每个本地化 1-10 张；App 跑 iPhone 时建议必备。
```

iPhone 6.5 英寸截图: Apple 官方规格，2026-05-05 核对 — src: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
```text
1284×2778 或 1242×2688 竖屏；如已提供 6.9 英寸截图，6.5 英寸可由 App Store Connect 缩放使用。
```

iPad 13 英寸截图: 当前工程支持 iPad — src: kitchen/kitchen.xcodeproj/project.pbxproj:369
```text
2064×2752 或 2048×2732 竖屏；如果保留 iPad 支持，则必须提供。
```

App 预览视频: Apple 官方规格，2026-05-05 核对 — src: https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications
```text
可选；每尺寸最多 3 段；15-30 秒；最大 500 MB；H.264、ProRes 422 HQ；扩展名 mov、m4v 或 mp4。
```

截图顺序建议:
```text
共享菜单、添加菜品、点菜购物车、当前订单、采购清单、历史订单、成员与邀请码、内购权益。
```

## I. 内购 / 订阅

内购类型: — src: kitchen/kitchen/Models/Entitlement.swift:4
```text
非消耗型一次性买断，无订阅。
```

商品 1 · 产品 ID: — src: kitchen/kitchen/Models/Entitlement.swift:37
```text
kitchen.dishes.essentials
```

商品 1 · 参考名称: （8/64）— 推断
```text
食单 50 道菜
```

商品 1 · 显示名称: （5/30）— 推断
```text
50 道菜
```

商品 1 · 描述: （25/45）— 推断
```text
将当前私厨菜品上限扩展至 50 道。
```

商品 1 · 价格档位:
```text
{待定}
```

商品 1 · 可用范围:
```text
全部可用
```

商品 1 · 家庭共享:
```text
建议开启
```

商品 1 · 是否在 App Store 推广:
```text
不推广
```

商品 1 · 推广图:
```text
{待补 1024×1024 JPG/PNG、RGB、72 dpi、无圆角}
```

商品 1 · App Review Screenshot:
```text
{待补 展示内购入口和购买前权益说明}
```

商品 1 · Review Notes:
```text
购买后当前私厨的菜品上限从免费 10 道扩展至 50 道。
```

商品 2 · 产品 ID: — src: kitchen/kitchen/Models/Entitlement.swift:38
```text
kitchen.dishes.unlimited
```

商品 2 · 参考名称: （8/64）— 推断
```text
食单 无限菜品
```

商品 2 · 显示名称: （4/30）— 推断
```text
无限菜品
```

商品 2 · 描述: （22/45）— 推断
```text
解除当前私厨菜品数量限制。
```

商品 2 · 价格档位:
```text
{待定}
```

商品 2 · 可用范围:
```text
全部可用
```

商品 2 · 家庭共享:
```text
建议开启
```

商品 2 · 是否在 App Store 推广:
```text
不推广
```

商品 2 · 推广图:
```text
{待补 1024×1024 JPG/PNG、RGB、72 dpi、无圆角}
```

商品 2 · App Review Screenshot:
```text
{待补 展示内购入口和购买前权益说明}
```

商品 2 · Review Notes:
```text
购买后当前私厨可维护无限菜品，一次买断，永久有效。
```

## J. TestFlight 测试信息

Beta App 描述: （73/4000）— 推断
```text
食单 Beta：家庭共享菜单与点餐工具。本轮重点验证菜品添加、订单流转、采购清单、多成员同步和一次性内购权益同步。
```

反馈邮箱:
```text
{待补}
```

营销 URL:
```text
{待补或留空}
```

隐私政策 URL: — src: kitchen/kitchen/Views/Settings/PageView.swift:15
```text
https://evilirving.github.io/family-concept
```

测试账号:
```text
同 D 节演示账号。
```

## K. 本地化

已支持语言: — src: kitchen/kitchen/InfoPlist.xcstrings:7
```text
en、ja、ko、zh-Hans、zh-Hant
```

包内显示名: — src: kitchen/kitchen/InfoPlist.xcstrings:7
```text
en=Meal Planner；ja=きょうの献立；ko=오늘 뭐 먹지；zh-Hans=食单；zh-Hant=食單
```

每种语言需要填写的商店字段:
```text
名称、副标题、推广文本、描述、关键词、这个版本的新功能、截图。
```

## 待办 Checklist

- [ ] 补真实主体名、版权、审核联系人电话和邮箱。
- [ ] 准备稳定审核账号、密码和可选邀请码。
- [ ] 确认 `https://evilirving.github.io/family-concept` 是否已经覆盖隐私政策、支持页和账号删除说明。
- [ ] 提交前补应用内账号删除路径或清晰外部删除入口，当前只发现退出登录。
- [ ] 决定是否保留 iPad 支持；保留则补 iPad 截图，不保留则修改 `TARGETED_DEVICE_FAMILY`。
- [ ] 确定两件内购的价格档位、审核截图和 1024×1024 推广图。
- [ ] 补日文、韩文、繁中商店页人工本地化。
