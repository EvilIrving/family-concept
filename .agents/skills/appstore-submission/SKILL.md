---
name: appstore-submission
version: 1.1.0
description: 扫描仓库，产出 App Store Connect「分发」页面所有可复制粘贴的字段，生成 docs/app-store-submission.zh.md 与 docs/app-store-submission.en.md。在用户准备上架 iOS App、需要填写 App Store Connect 元数据、或要求生成 App Store 上架清单时使用。
allowed-tools:
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Bash
---

# App Store Connect 上架填表 skill

目标：扫一遍仓库，把 App Store Connect 「分发」页所有需要人工填写的字段生成成两份 markdown（中文 + 英文），用户能从文档里直接复制纯文本粘贴到 App Store Connect。

## 输出文件

写到 `docs/`：
- `docs/app-store-submission.en.md` —— English（主语言）
- `docs/app-store-submission.zh.md` —— 简体中文（国内）

## 扫描清单（按重要性顺序）

执行前先读这些来源，**有引用就写来源路径**，让用户能验证：

1. **Info.plist / project.pbxproj**：Bundle ID、版本号、build、最低系统、Capabilities、UsageDescription
2. **`*.entitlements`**：iCloud、推送、Sign in with Apple、HealthKit 等
3. **`Localizable.xcstrings` / `InfoPlist.xcstrings`**：已支持语言、App 显示名
4. **网络代码 grep**：`URLSession`、`Alamofire`、第三方 SDK（Firebase、AdMob、Sentry、Bugsnag、AppsFlyer、友盟、神策…）→ 决定隐私问卷
5. **StoreKit 配置 / `.storekit` 文件 / 订阅模型**：内购清单
6. **加密相关**：`CryptoKit`、`CommonCrypto`、`CC_SHA`、HTTPS-only → 出口合规答案
7. **`docs/`（含 `app-icon-master-prompt.md`）、`README.md`、`AGENTS.md`、`CLAUDE.md`、`todo.md`**：app 定位、卖点、品牌描述
8. **AdMob/IDFA 关键词**：`AppTrackingTransparency`、`ASIdentifierManager`、`GADMobileAds` → IDFA 问卷
9. **登录/账号**：是否有用户系统 → 决定是否需要演示账号、是否触发 Sign in with Apple 强制项
10. **儿童相关、UGC、聊天**：决定分级问卷答案
11. **排行榜 AEO/ASO 参考**：如可联网，必须抓取目标市场 iPhone Top Free Apps 前 50 名，而不是只看同类竞品。记录前 50 的 App name、开发者、主类别、subtitle 或榜单露出语、描述首句，并总结它们如何用品牌名、功能词、场景词和价值主张组织搜索结果露出。

## AEO / ASO 研究基线

执行前先按 Apple 官方规则校准：App name 最多 30 字符，应该简单、好记、易拼写，并暗示 App 做什么；subtitle 最多 30 字符，用来补充价值和典型用途；keywords 最多 100 字符，逗号分隔且逗号后不加空格；description 首句最重要，不要为了搜索结果堆关键词；promotional text 不影响搜索排名。App Store search 的文本相关性来自 title、subtitle、keywords、primary category，搜索结果也可能基于 App Store Connect 元数据生成 app tags，所以 AEO 要靠准确、自然、结构化的语义，而不是机械堆词。

排行榜样本必须覆盖 Top Free 前 50 名的多品类头部 App，不限同类。优先用 Apple RSS `https://rss.marketingtools.apple.com/api/v2/{country}/apps/top-free/50/apps.json` 获取榜单，再用 iTunes Lookup 或 App Store 页面补充主类别、描述首句和可见 subtitle；如某些 App 详情抓不到，要保留榜单名称并继续分析其命名结构。不要复制这些 App 的文案，也不要把它们的品牌名放入 keywords；只抽象它们的命名结构和信息密度。

前 50 样本 notes 必须按模式归类，而不是逐个罗列后结束。至少归纳这些模式：强品牌裸名或轻功能补语、品牌 + 类别词、品牌 + 动词短语、品牌 + 场景结果、功能/品类名直接命名、描述首句先给结果、描述首句先给身份、描述首句先给规模或信任背书。生成文档时不需要贴出 50 个 App 的完整清单，但 ASO/AEO 决策说明必须引用这些模式。

从排行榜样本里提炼这些模式后再写字段：头部 App 通常保留短品牌名，让 subtitle 承担“AI chat/search”“assistant for life and work”“photo/video editor”“shopping app/package tracker”“food delivery/grocery/retail”“secure/fast/organized email”这类功能和场景；强品牌少堆词，弱品牌用名称或 subtitle 补足类别语义；subtitle 往往是搜索结果里最短的转化句；描述首句先讲用户要得到的结果，而不是产品自我介绍。

生成前必须做内部 AEO notes，至少回答四件事：这个 App 的品牌词是什么，最核心类别词是什么，搜索结果里 30 字符内最该让用户看到什么，description 首句要触发哪个用户场景。若没有联网，必须在生成文档的待办里写明“发布前用 Apple 排行榜、Apple Ads keyword suggestions 或 Search Ads 数据复核名称、subtitle、keywords”。

## 名称、Subtitle、关键词、描述规则

App Store 名称不是简单塞关键词。强品牌优先保留品牌并只补一个高意图类别词；弱品牌或新品牌可以采用 `品牌 - 类别词`、`品牌: 类别词` 或 `品牌 类别词`，但右侧只放一个最关键短语，不允许塞 2–3 组关键词。名称要避免 generic-only、竞品相似、夸张词、无法验证词和排行榜品牌词。

Subtitle 是搜索结果里的第二句文案，必须承担名称没说完的“用途 + 结果”。优先写功能和场景，不写泛泛口号；不要重复名称、keywords 或 category 已覆盖的词；不要用 `best`、`ultimate`、`simple`、`smart` 这类单独存在时没有检索意图的形容词。中文优先自然口语场景，英文优先用户实际搜索短语。

Keywords 字段必须先去重，再排序。不要重复 App name、subtitle、category、单复数、同根词、`app`、无意义虚词、竞品名、商标、名人、热点词或代码无法支撑的词。关键词策略不是只选最大泛词，而是组合高意图泛词、具体功能词和场景词；新 App 应优先争取中等竞争但转化更清晰的词。

Description 服务 AEO 和转化，不服务关键词堆砌。首句必须在用户点开全文前说明“谁在什么场景下得到什么结果”；正文采用一个短开场 + 3–5 个场景标题 + 隐私/价格/限制收尾。描述里要自然写出实体关系，例如用户、内容、动作、结果、同步对象、权限边界，让 LLM 生成的 app tags 能理解 App 的真实用途。

Promotional text 不影响搜索排名，只写当前最强卖点、活动、版本亮点或一句转化文案，不用来堆关键词。

## 输出文件结构（中英文独立生成）

中英文两份文档按 App Store Connect 左侧导航分节，但**不是互译关系**。两份内容必须基于各自市场的 AEO/ASO 搜索习惯、用户表达和转化逻辑独立生成。采用“字段说明行 + 纯文本复制块”格式，便于扫读，也便于直接复制。

````
名称: `BRAND - CORE USE` 格式（2/30）— src: kitchen/kitchen/Info.plist:8
```text
食单 - 家庭菜单
```

副标题: （10/30）
```text
家庭私厨的菜单与点餐
```

Bundle ID: 只读核对 — src: kitchen/kitchen.xcodeproj/project.pbxproj:357
```text
cain.com.kitchen
```
````

格式规则：
- 每个需要粘贴到 App Store Connect 的字段，都必须给一个紧跟字段说明行的 `text` 代码块，代码块里只放最终要复制的值。
- 代码块内禁止出现 Markdown 语法、反引号、引用符号 `>`、列表符号、来源、长度统计、解释文字或 placeholder 提醒，除非该字段本身就需要这些字符。
- 字段说明行只放字段名、长度统计、来源和必要提醒；不要让用户复制字段说明行。
- 短字段也必须用 `text` 代码块，不要只用行内反引号。
- 长描述、审核备注、隐私问卷答案、新功能说明也必须用纯文本代码块；允许在代码块内保留自然段空行，但不要使用 Markdown 引用或项目符号。
- 长度限制写在字段说明行括号里 `（已用/上限）`；来源写在字段说明行末尾 `— src: path:line`。
- 不生成备选字段、不写 `备选:`，只输出一个最终推荐值。
- App Store 名称默认采用 `BRAND - CORE USE`、`BRAND: CORE USE` 或 `BRAND CORE USE` 之一；左侧是短品牌名或主名称，右侧只放一个最核心用途短语；整体必须 ≤30 字符。不要把 2–3 组关键词塞进名称。
- 包内图标显示名仍单独列出，不强制使用 App Store 名称；图标显示名优先短、清楚、不截断。
- 只读核对项如果不需要粘贴，也可以不给代码块，但 Bundle ID、版本号、build 这类常被复制核对的字段建议仍给代码块。

### 必须覆盖的板块

**A. App 信息（一次性，所有版本共用）**
- App 名称（30 字符，默认 `BRAND - CORE USE` / `BRAND: CORE USE` / `BRAND CORE USE` 三选一，按排行榜前 50 模式选择最自然的一种）
- 副标题（30 字符）
- SKU（内部 ID，不展示给用户；如仓库无依据则给一个稳定建议值并标 `— 推断`）
- Apple ID（如已创建 App Store Connect 记录则列出；扫不到则写 `{待 App Store Connect 自动生成}`）
- Bundle ID（只读，列出供核对）
- 隐私政策 URL（iOS 必填；如果仓库只有占位链接，明确标 `{待确认}`）
- 主要语言
- 主分类 + 次分类（给推荐 + 一句理由）
- 内容版权
- 许可协议（默认 Apple 标准许可；如需要自定义则写 `{待补}`）
- 年龄分级（直接给问卷答案，每题写「答案 + 一句理由」）
- DSA / 欧盟交易者状态（Digital Services Act；如没有主体信息，写 `{待账号主体确认}`）
- 标签和标记 URL（Labels and Markings URLs；如不适用，写 `不适用`）
- 韩国、中国大陆、越南可用性相关声明（如计划上架对应地区，列出待确认项）

**B. 当前版本（1.0）**
- 推广文本（170 字符，可随时改）
- 描述（4000 字符）
- 关键词（100 字符，逗号分隔，给一份排好优先级的清单）
- AEO/ASO 决策说明（不需要复制到 App Store Connect，说明最终名称、subtitle、关键词和描述首句如何吸收前 50 榜单模式；不提供备选）
- 支持网址 / 营销网址（如无，给 placeholder + 提醒）
- 「这个版本的新功能」（v1.0 写首发文案）
- 版本号与 build（从 project.pbxproj 读取）
- 版本发布设置（手动发布 / 审核通过后自动发布 / 指定日期发布，给推荐）
- 分阶段发布（Phased Release；首发通常不适用，更新版本才需要）
- 重置评分（Reset rating；首发不适用，更新版本才需要）
- 版权
- 联系信息（保留 placeholder）

**B2. 价格与可用范围**
- App 价格（免费 / 付费价格档位）
- 可用国家或地区（默认全部可用；如有中国大陆、韩国、越南特殊要求，回链 A 节待确认项）
- 预订（Pre-Order；首发如不做预订则写不启用）
- 商务与教育分发（Business and Education；默认不启用，除非用户指定）
- 最低兼容版本设置（Last-Compatible Version；首发通常不适用）
- 税务类别（Tax Category；如没有明确业务依据，写 `{待 App Store Connect/税务主体确认}`）

**C. App 隐私（直接给问卷答案）**
按 Apple 数据类型分组，每个类型答 收集/不收集，链接到/不链接到用户、用于追踪/不用于追踪、用途。常见组：
- 联系信息、健康与健身、财务信息、位置、敏感信息、通讯录、用户内容、浏览历史、搜索历史、标识符、购买记录、使用数据、诊断
- 基于代码扫描结果给答案；没扫到的明确写「不收集」
- Privacy Policy URL 与 User Privacy Choices URL 单独列出；账号删除、数据访问或隐私选择链接没有实现时必须写入 checklist。

**C2. App 辅助功能**
- Accessibility URL（如无，写 `{待补或留空}`）
- Accessibility Support / 辅助功能营养标签（依据代码和实际功能给初稿，无法自动确认的标 `{待人工核对}`）

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
每个产品列：产品 ID、参考名称、显示名称、描述、价格档位、可用范围、家庭共享、是否在 App Store 推广、推广图、App Review Screenshot、Review Notes。
内购显示名称必须 2–30 字符，描述必须 ≤45 字符，推广图必须 JPG/PNG、1024×1024、RGB、72 dpi、无圆角。

**J. TestFlight 测试信息**（顺手给）
- Beta App 描述、反馈邮箱、营销 URL、隐私政策

**K. 本地化**
列出 xcstrings 中已支持的语言，提醒哪些字段需要每种语言一份。

## 执行步骤

1. **盘点**：用 Glob/Grep 把本地 10 类来源全部摸一遍，做 product facts notes
2. **排行榜研究**：如联网可用，抓取目标市场 iPhone Top Free Apps 前 50 名，补充详情后做 AEO/ASO pattern notes
3. **关键词矩阵**：按语言分别列出任务词、对象词、场景词、差异词，删除重复词、类别词、竞品词、商标词和代码无法支撑的词
4. **元数据决策**：先定 App 名称，再定 subtitle，再定 keywords，最后写推广文本和描述，确保字段之间不重复浪费字符
5. **问卷决策**：对隐私、加密、IDFA、分级逐题给答案，每题一句理由
6. **草拟中文版**：按板块结构写 `docs/app-store-submission.zh.md`
7. **独立生成英文版**：写 `docs/app-store-submission.en.md`，英文 App 名称、副标题、推广文本、描述、关键词、新功能文案必须按英语市场 AEO/ASO 逻辑重新设计，不能从中文稿翻译或改写
8. **校验**：检查名称 ≤30、subtitle ≤30、关键词 ≤100 且逗号后无空格、描述 ≤4000、内购描述 ≤45、无 blockquote、无备选字段
9. **末尾加 checklist**：一个总的 ✅ 待办列表，提醒用户哪些字段需要他自己补（联系电话、URL、截图、隐私政策链接等）

## 风格要求

- **复制块优先**：字段说明行负责解释，紧随其后的 `text` 代码块负责复制；不要再把正式值只写在行内反引号里。
- 禁止使用 blockquote 承载 App Store Connect 要复制的内容，因为复制时会带上 `>`。
- 仅 checklist、扫描说明这类不需要复制到 App Store Connect 的内容可以使用普通 Markdown。
- 不输出备选名称、备选副标题、备选关键词；如拿不准最终值，先依据产品定位选一个最稳版本，不要把选择题留在文档里。
- 中英文商店页必须独立生成：中文优先围绕中文用户会搜和会被打动的词，例如家庭菜单、备餐、买菜、点菜、今天吃什么；英文优先围绕英语市场会搜和会被打动的词，例如 meal planner、family menu、grocery list、dinner plan、meal planning。
- 名称、subtitle、keywords 三者必须去重：名称出现过的核心词不要再塞进 subtitle 或 keywords；subtitle 出现过的词也不要再放进 keywords，除非该语言下拆词会损失核心语义。
- keywords 逗号后不加空格，避免浪费 100 字符预算；不要写类别名、`app`、竞品名、排行榜品牌名、商标、无关热词、重复词、单复数重复或 Apple 明确禁止的词。
- 描述首句必须像排行榜头部 App 的商店页文案，先写用户结果或使用场景，不要像产品说明书。正文优先用自然段标题组织，例如「买菜前自动看清要准备什么」或 `A grocery list from the active meal`。
- AEO/ASO 决策说明只解释最终选择如何吸收前 50 榜单模式，不能给备选方案；如果联网不可用，要明确提醒发布前用 Apple 排行榜、Apple Ads keyword suggestions 或真实 Search Ads 数据复核。
- 禁止把中文标题、副标题、推广文本、描述、关键词逐句翻译成英文；也禁止把英文逐句翻译成中文。
- 中英文可以共享代码事实、功能事实、隐私事实、审核事实、版本号、Bundle ID、内购 ID，但营销表达、关键词排序、标题关键词和描述结构必须独立。
- 每份文档都要单独计算字符数，不要沿用另一语言的长度判断。
- 推断的标 `— 推断`；代码确认的标 `— src: file:line`，写在行尾
- 不要客套话、不要解释 App Store Connect 是什么
- 关键词清单：按搜索量优先级排序，逗号分隔，最后总长 ≤100 字符（含空格按 Apple 规则计算）

## 不要做的事

- 不要生成截图、不要生成图标
- 不要伪造 URL、邮箱、电话
- 不要在没有依据时编造功能描述 —— 拿不准就读更多代码或问用户
- 不要省略问卷题目，即使答案是「否」也要列出来，让用户能逐项核对
