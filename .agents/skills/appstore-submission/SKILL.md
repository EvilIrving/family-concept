---
name: appstore-submission
version: 1.0.0
description: 扫描仓库，产出 App Store Connect「分发」页面所有可复制粘贴的字段，生成 appstore-submission.zh.md 与 appstore-submission.en.md。在用户准备上架 iOS App、需要填写 App Store Connect 元数据、或要求生成 App Store 上架清单时使用。
allowed-tools:
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Bash
---

# App Store Connect 上架填表 skill

目标：扫一遍仓库，把 App Store Connect 「分发」页所有需要人工填写的字段生成成两份 markdown（中文 + 英文），用户直接复制粘贴即可。

## 输出文件

写到项目根目录：
- `appstore-submission.zh.md` —— 简体中文（主语言）
- `appstore-submission.en.md` —— English（兜底/海外）

## 扫描清单（按重要性顺序）

执行前先读这些来源，**有引用就写来源路径**，让用户能验证：

1. **Info.plist / project.pbxproj**：Bundle ID、版本号、build、最低系统、Capabilities、UsageDescription
2. **`*.entitlements`**：iCloud、推送、Sign in with Apple、HealthKit 等
3. **`Localizable.xcstrings` / `InfoPlist.xcstrings`**：已支持语言、App 显示名
4. **网络代码 grep**：`URLSession`、`Alamofire`、第三方 SDK（Firebase、AdMob、Sentry、Bugsnag、AppsFlyer、友盟、神策…）→ 决定隐私问卷
5. **StoreKit 配置 / `.storekit` 文件 / 订阅模型**：内购清单
6. **加密相关**：`CryptoKit`、`CommonCrypto`、`CC_SHA`、HTTPS-only → 出口合规答案
7. **`docs/`、`README.md`、`AGENTS.md`、`CLAUDE.md`、`LOGO_PROMPT.md`、`todo.md`**：app 定位、卖点、品牌描述
8. **AdMob/IDFA 关键词**：`AppTrackingTransparency`、`ASIdentifierManager`、`GADMobileAds` → IDFA 问卷
9. **登录/账号**：是否有用户系统 → 决定是否需要演示账号、是否触发 Sign in with Apple 强制项
10. **儿童相关、UGC、聊天**：决定分级问卷答案

## 输出文件结构（两份内容相同，仅语言不同）

按 App Store Connect 左侧导航分节。**采用极简单行格式**，一字段一行，便于扫读复制：

```
名称: `食单`  （2/30）
副标题: `家庭私厨的菜单与点餐`  （10/30）；备选: `一家人的菜单与下单`
Bundle ID: `cain.com.kitchen`
主要类别: 美食佳饮；次要类别: 生活
```

格式规则：
- 字段名后直接 `:`，值用反引号包裹（短值）或独占一行（长描述）
- 长度限制写在括号里 `（已用/上限）`，不另起 bullet
- 备选用 `；备选:` 衔接同一行；多个备选用 `/` 分隔
- 来源用行尾小字 `— src: path:line` 标注，没有就省略，**不再用「位置 / 限制 / 建议内容 / 来源」四行结构**
- 仅描述/隐私问卷答案这类多行内容才用 blockquote

### 必须覆盖的板块

**A. App 信息（一次性，所有版本共用）**
- App 名称（30 字符）
- 副标题（30 字符）
- Bundle ID（只读，列出供核对）
- 主要语言
- 主分类 + 次分类（给推荐 + 备选理由）
- 内容版权
- 年龄分级（直接给问卷答案，每题写「答案 + 一句理由」）

**B. 当前版本（1.0）**
- 推广文本（170 字符，可随时改）
- 描述（4000 字符）
- 关键词（100 字符，逗号分隔，给一份排好优先级的清单）
- 支持网址 / 营销网址（如无，给 placeholder + 提醒）
- 「这个版本的新功能」（v1.0 写首发文案）
- 版权
- 联系信息（保留 placeholder）

**C. App 隐私（直接给问卷答案）**
按 Apple 数据类型分组，每个类型答 收集/不收集，链接到/不链接到用户、用于追踪/不用于追踪、用途。常见组：
- 联系信息、健康与健身、财务信息、位置、敏感信息、通讯录、用户内容、浏览历史、搜索历史、标识符、购买记录、使用数据、诊断
- 基于代码扫描结果给答案；没扫到的明确写「不收集」

**D. App 审核信息**
- 联系人姓名/电话/邮箱（placeholder）
- 演示账号（如检测到登录系统：列出测试账号字段；否则写「不需要」）
- 备注（写给审核员看：本 app 是做什么的、关键路径、特殊权限解释）

**E. 出口合规 / 加密**
- 「是否使用加密」直接给答案（基于代码扫描）
- 若仅用 HTTPS / Apple 标准 API → 通常 ITSAppUsesNonExemptEncryption=false，免提交合规
- 写明依据

**F. 内容版权 / 第三方内容**
- 是否包含第三方内容、是否有授权

**G. 广告标识符（IDFA）**
- 是否使用 → 直接答案 + 用途勾选

**H. 截图与预览（清单 + 规格）**
列出必须的设备尺寸（iPhone 6.9"、6.5"、iPad 13" 如果支持）、分辨率、最少/最多张数、视频规格。不生成图，只列 todo 清单。

**I. 内购 / 订阅**（如有 StoreKit）
每个产品列：产品 ID、参考名称、显示名称、描述、价格档位、订阅组、家庭共享、推广图。

**J. TestFlight 测试信息**（顺手给）
- Beta App 描述、反馈邮箱、营销 URL、隐私政策

**K. 本地化**
列出 xcstrings 中已支持的语言，提醒哪些字段需要每种语言一份。

## 执行步骤

1. **盘点**：用 Glob/Grep 把上面 10 类来源全部摸一遍，做个内部 notes
2. **决策**：对问卷题目（隐私、加密、IDFA、分级）逐题给答案，每题一句理由
3. **草拟中文版**：按板块结构写 `appstore-submission.zh.md`
4. **翻译英文版**：写 `appstore-submission.en.md`，App 名称/副标题/关键词/描述要重新本地化（不是机翻），关键词换成英文搜索词
5. **末尾加 checklist**：一个总的 ✅ 待办列表，提醒用户哪些字段需要他自己补（联系电话、URL、截图、隐私政策链接等）

## 风格要求

- **极简行内格式优先**：`字段: \`值\`  （n/上限）；备选: \`值2\``，不要为每个字段开 H3 + 多个 bullet
- 仅长描述（>100 字）、隐私问卷分组答案、审核备注才用 blockquote 或多行
- 推断的标 `— 推断`；代码确认的标 `— src: file:line`，写在行尾
- 不要客套话、不要解释 App Store Connect 是什么
- 关键词清单：按搜索量优先级排序，逗号分隔，最后总长 ≤100 字符（含空格按 Apple 规则计算）

## 不要做的事

- 不要生成截图、不要生成图标
- 不要伪造 URL、邮箱、电话
- 不要在没有依据时编造功能描述 —— 拿不准就读更多代码或问用户
- 不要省略问卷题目，即使答案是「否」也要列出来，让用户能逐项核对
