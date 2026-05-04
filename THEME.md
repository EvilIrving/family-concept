# Kitchen Theme Color Token

## Product Lens

Kitchen 是一个家庭私厨协作应用，核心不是餐厅经营、排队点餐或商业 POS，而是家庭成员围绕「今天吃什么、谁来准备、需要买什么」形成的轻量协作。界面必须长期可读、低压力、可快速扫视，并且在菜单图片、订单状态、购物清单、成员权限之间保持清楚的层级。

品牌气质应当是温暖、可靠、克制、生活化，而不是高刺激、促销感或科技感。目标用户更接近家庭组织者、伴侣、室友、小家庭成员，他们需要一种「像厨房器物一样可靠」的视觉系统：不冷、不吵、不幼稚，同时能在行动按钮和状态反馈上足够明确。

## Grayscale First

色彩系统先从灰度稿成立：页面底色、卡片、列表行、输入框、分割线、描边、正文、弱化信息和禁用态都必须在没有品牌色的情况下完成信息架构。中性色不使用纯黑纯白作为主要界面色，而是使用带轻微陶土暖灰倾向的 gray 色板，让无品牌色界面仍然有家庭厨房的温度。

Light Mode 使用 gray50 作为页面底色、gray100 作为次级背景、gray200 作为卡片和输入区边界，正文落在 gray800 到 gray900。Dark Mode 先按反向映射生成，再压低最深背景的蓝黑感、提高正文亮度、降低边界对比，避免夜间界面出现压迫感。

## Primary Color Choice

主色选择 Clay Terracotta，中心色为 primary500 `#B85C3C`。它介于陶土、烘焙器具和温热餐桌之间，能匹配家庭私厨的核心使命：把分散的家庭饮食决策变成可协作、可执行、可复用的日常系统。

从色彩心理看，陶土色比绿色更少工具感，比橙色更少促销感，比红色更少警报感，比蓝色更少企业后台感。它适合用于添加菜品、创建订单、确认操作和当前选中状态，在界面直觉上像「可以按下去的温暖器物」，同时不会抢走菜品照片本身的注意力。

低饱和度判断：整套品牌色采用中等偏克制的饱和度，而不是全面低饱和。这样能保留家庭产品的柔和感，同时让 primary、warning、error 等状态在列表、订单流和底部浮层中仍然有足够识别度；错误色和警告色都降低了刺眼度，避免单个功能色跳出系统。

## Light Palette Tokens

### Neutral Gray

| Token | Hex | Usage |
| --- | --- | --- |
| gray50 | `#FAF8F5` | 页面主背景、空状态背景 |
| gray100 | `#F2EEE9` | 次级页面背景、列表分组背景 |
| gray200 | `#E2D9D0` | 常规描边、弱分割线 |
| gray300 | `#CDBFB2` | 强分割线、禁用描边 |
| gray400 | `#AFA094` | 占位符、低优先级图标 |
| gray500 | `#8D7E73` | 弱化说明、辅助标签 |
| gray600 | `#6F6258` | 次级正文、设置说明 |
| gray700 | `#51463E` | 强辅助文字、次级标题 |
| gray800 | `#332C27` | 主标题、正文 |
| gray900 | `#211C18` | 最高强调文字、Toast 深底 |

### Brand And Semantic Palettes

| Scale | primary | secondary | accent | success | warning | error | info |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 50 | `#FFF3ED` | `#EEF8F3` | `#FFF0F4` | `#ECF8F1` | `#FFF7E6` | `#FFF0EE` | `#ECF7FA` |
| 100 | `#FDE3D7` | `#D7EFE5` | `#FBD8E2` | `#D4EFDF` | `#FCE9BF` | `#FAD8D3` | `#D4EEF4` |
| 200 | `#F7C3AD` | `#AEDCCB` | `#F3AEC1` | `#A9DCBE` | `#F6D080` | `#F0ABA2` | `#A8DAE5` |
| 300 | `#EC9E7D` | `#84C4AD` | `#E681A0` | `#7CC69A` | `#EEB84D` | `#E27B70` | `#7DC3D2` |
| 400 | `#D97956` | `#5BAA8E` | `#D55B80` | `#52AB78` | `#D99A27` | `#CC554B` | `#58AABD` |
| 500 | `#B85C3C` | `#438D72` | `#B84769` | `#3F8E63` | `#B8781F` | `#A9433B` | `#438C9D` |
| 600 | `#984A31` | `#34745D` | `#983954` | `#31754F` | `#946018` | `#8C352F` | `#357485` |
| 700 | `#783927` | `#285B49` | `#782C43` | `#265C3E` | `#724913` | `#6E2925` | `#2A5B69` |
| 800 | `#57291D` | `#1D4235` | `#592132` | `#1C432E` | `#50330E` | `#501F1B` | `#1F424D` |
| 900 | `#381A13` | `#122A22` | `#391520` | `#112A1D` | `#332009` | `#321311` | `#132A31` |

## Dark Palette Tokens

Dark Mode 先按 Light Mode 灰度反向映射生成，即 light gray50 接近 dark gray900、light gray900 接近 dark gray50；随后把背景向暖黑微调，把正文从纯白风险中拉回米白，把描边降低存在感，并把品牌色中段提亮到暗背景上可识别。

| Token | Hex | Usage |
| --- | --- | --- |
| gray50 | `#F7F1EA` | 暗色主文字、最高对比文本 |
| gray100 | `#E9DDD3` | 暗色正文、亮图标 |
| gray200 | `#BBAA9E` | 暗色弱化文字 |
| gray300 | `#9B8B80` | 暗色占位符、禁用文字 |
| gray400 | `#766A62` | 暗色禁用描边 |
| gray500 | `#5B5049` | 暗色强描边 |
| gray600 | `#463C35` | 暗色常规描边、分割线 |
| gray700 | `#332B26` | 暗色次级容器 |
| gray800 | `#241E1A` | 暗色卡片、输入框 |
| gray900 | `#171310` | 暗色页面主背景 |

| Scale | primary | secondary | accent | success | warning | error | info |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 50 | `#381A13` | `#122A22` | `#391520` | `#112A1D` | `#332009` | `#321311` | `#132A31` |
| 100 | `#57291D` | `#1D4235` | `#592132` | `#1C432E` | `#50330E` | `#501F1B` | `#1F424D` |
| 200 | `#783927` | `#285B49` | `#782C43` | `#265C3E` | `#724913` | `#6E2925` | `#2A5B69` |
| 300 | `#984A31` | `#34745D` | `#983954` | `#31754F` | `#946018` | `#8C352F` | `#357485` |
| 400 | `#B85C3C` | `#438D72` | `#B84769` | `#3F8E63` | `#B8781F` | `#A9433B` | `#438C9D` |
| 500 | `#D97956` | `#5BAA8E` | `#D55B80` | `#52AB78` | `#D99A27` | `#CC554B` | `#58AABD` |
| 600 | `#EC9E7D` | `#84C4AD` | `#E681A0` | `#7CC69A` | `#EEB84D` | `#E27B70` | `#7DC3D2` |
| 700 | `#F7C3AD` | `#AEDCCB` | `#F3AEC1` | `#A9DCBE` | `#F6D080` | `#F0ABA2` | `#A8DAE5` |
| 800 | `#FDE3D7` | `#D7EFE5` | `#FBD8E2` | `#D4EFDF` | `#FCE9BF` | `#FAD8D3` | `#D4EEF4` |
| 900 | `#FFF3ED` | `#EEF8F3` | `#FFF0F4` | `#ECF8F1` | `#FFF7E6` | `#FFF0EE` | `#ECF7FA` |

## Semantic Tokens

语义 token 不暴露具体颜色名，业务页面和组件只消费稳定语义名。Palette 可以替换，Semantic API 尽量不变。

| Token Name | Light Hex | Dark Hex | Usage | Contrast Risk | Manual Review |
| --- | --- | --- | --- | --- | --- |
| backgroundPrimary | `#FAF8F5` | `#171310` | 页面底层背景 | 低 | 真机检查大面积页面是否偏黄或偏暗 |
| backgroundSecondary | `#F2EEE9` | `#241E1A` | 分组背景、列表区背景 | 低 | 检查与卡片的层级是否足够 |
| backgroundElevated | `#ECE6DF` | `#332B26` | Sheet、弹层、浮动区域 | 中 | 暗色模式下避免浮层过亮 |
| surfacePrimary | `#FFFCF8` | `#241E1A` | 卡片、输入框、主要容器 | 低 | iOS 材质叠加后需复核 |
| surfaceSecondary | `#F2EEE9` | `#332B26` | 次级卡片、列表行 | 低 | 与 backgroundSecondary 不应粘连 |
| surfaceTertiary | `#E2D9D0` | `#463C35` | 禁用填充、低权重容器 | 中 | 禁用态文字需要同屏复核 |
| textPrimary | `#211C18` | `#F7F1EA` | 主标题、正文、关键数字 | 低 | Dynamic Type 放大后检查密度 |
| textSecondary | `#6F6258` | `#D8C9BC` | 说明文字、设置副文案 | 低 | 小字号不得低于 13pt |
| textTertiary | `#8D7E73` | `#9B8B80` | 占位符、弱标签、辅助图标 | 中 | 小字和图标需检查 3:1 |
| textDisabled | `#AFA094` | `#766A62` | 禁用文字 | 中 | 不承载关键业务信息 |
| borderSubtle | `#E2D9D0` | `#463C35` | 卡片描边、输入框描边 | 低 | 暗色 OLED 上可能偏弱 |
| borderStrong | `#CDBFB2` | `#5B5049` | 区域分割、底部栏上边线 | 低 | 不用于密集列表每一行 |
| divider | `#E2D9D0` | `#463C35` | 细分割线 | 中 | 1px 线在低亮屏需复核 |
| accentPrimary | `#B85C3C` | `#EC9E7D` | 主按钮、选中态、主要 CTA | 中 | 白字在 light 上需用 onAccentPrimary |
| accentPrimaryPressed | `#984A31` | `#D97956` | 主按钮按下态 | 低 | 动效状态需检查跳变 |
| accentPrimarySubtle | `#FFF3ED` | `#57291D` | 选中 chip 背景、轻量提示底 | 中 | 文字需搭配 accentPrimaryText |
| accentPrimaryText | `#783927` | `#FDE3D7` | 浅底品牌文字、选中 chip 文本 | 低 | 不用于长正文 |
| onAccentPrimary | `#FFF8F3` | `#211C18` | 主色实底上的文字和图标 | 中 | light 主色按钮白字需人工测 AA |
| accentSecondary | `#438D72` | `#84C4AD` | 次级正向操作、协作状态 | 低 | 不与 success 混用 |
| accentDecorative | `#B84769` | `#E681A0` | 徽章、图表点缀、小面积强调 | 中 | 不用于错误或主要 CTA |
| success | `#3F8E63` | `#7CC69A` | 成功、已完成、可用状态 | 低 | 与 secondary 同屏需靠文案区分 |
| successBackground | `#ECF8F1` | `#1C432E` | 成功提示浅底 | 低 | 绿色文字需用 successText |
| successText | `#265C3E` | `#D4EFDF` | 成功浅底文字 | 低 | 小字号复核 |
| warning | `#B8781F` | `#EEB84D` | 警告、待处理、即将超限 | 中 | 黄底白字不可用 |
| warningBackground | `#FFF7E6` | `#50330E` | 警告提示浅底 | 低 | 和品牌暖色同屏需有图标 |
| warningText | `#724913` | `#FCE9BF` | 警告浅底文字 | 低 | 采购清单数量状态需复核 |
| error | `#A9433B` | `#E27B70` | 错误、删除、失败 | 低 | 破坏性操作需要二次确认 |
| errorBackground | `#FFF0EE` | `#501F1B` | 错误提示浅底 | 低 | Toast 和表单错误需分别检查 |
| errorText | `#6E2925` | `#FAD8D3` | 错误浅底文字 | 低 | 不与 primary 暖色混淆 |
| info | `#438C9D` | `#7DC3D2` | 信息、同步、系统提示 | 低 | 暗色模式不要过亮发蓝 |
| infoBackground | `#ECF7FA` | `#1F424D` | 信息提示浅底 | 低 | 与系统蓝通知区分 |
| infoText | `#2A5B69` | `#D4EEF4` | 信息浅底文字 | 低 | 小字号复核 |
| disabledBackground | `#E2D9D0` | `#332B26` | 禁用按钮、禁用输入区 | 中 | 禁用态不能像可点击卡片 |
| disabledForeground | `#AFA094` | `#766A62` | 禁用图标和文字 | 中 | 不放关键价格或数量 |
| focusRing | `#EC9E7D` | `#F7C3AD` | 输入聚焦、可访问性焦点 | 中 | iOS focus/VoiceOver 需真机检查 |
| scrim | `#211C1852` | `#00000099` | 遮罩、弹层背景压暗 | 中 | 图片裁剪和 sheet 场景需复核 |
| toastBackground | `#211C18` | `#F7F1EA` | Toast 实底 | 低 | Toast 文字颜色必须反向 |
| toastForeground | `#FFF8F3` | `#211C18` | Toast 文本和图标 | 低 | 检查多语言长文案 |

## Usage Mapping

| UI Area | Token |
| --- | --- |
| App root background | backgroundPrimary |
| Tab page background | backgroundPrimary |
| Grouped settings background | backgroundSecondary |
| Cards and menu dish cells | surfacePrimary |
| Search field and text fields | surfacePrimary, borderSubtle, textPrimary, textTertiary |
| Bottom cart bar | accentPrimary, onAccentPrimary |
| Primary button | accentPrimary, accentPrimaryPressed, onAccentPrimary |
| Secondary button | accentPrimarySubtle, accentPrimaryText |
| Destructive button | error, errorBackground, errorText |
| Status pill: completed | successBackground, successText |
| Status pill: pending | warningBackground, warningText |
| Status pill: syncing/info | infoBackground, infoText |
| Empty state title | textPrimary |
| Empty state description | textSecondary |
| Member role badge | accentSecondary with surfacePrimary |
| Purchase or upgrade emphasis | accentDecorative, accentPrimary |
| Disabled control | disabledBackground, disabledForeground |
| Divider and card stroke | borderSubtle or divider |
| Sheet overlay | scrim, backgroundElevated |

## Implementation Notes

色阶生成基于 HSL/OKLCH 的视觉逻辑：浅色阶提高亮度并降低色度，中段保持识别度，深色阶降低亮度并略收饱和，避免简单线性改 hex 导致 300 到 700 的色相漂移。Light Mode 的 primary500、success500、error500、info500 都可作为状态前景或实底色；warning500 不建议承载白字，应优先使用 warningBackground 搭配 warningText。

Dark Mode 的品牌色不直接复用 Light Mode 500，而是把可交互中心上移到 600 到 700 区间，以保证暗背景上的可见度。错误色在暗色模式保持玫瑰陶红方向，不使用高饱和荧光红，避免订单失败、删除确认和 Toast 场景产生刺眼跳色。

人工复核重点应放在主按钮白字对比、warning 小字号、禁用态与可点击态区分、菜品图片复杂背景上的浮层按钮、以及中文长文案在 Toast 和 Sheet 中的可读性。
