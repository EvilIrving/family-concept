# Cooklist App Icon

推荐方向：绿色圆角底板 + 象牙白碗形主体 + 金色勾形蒸汽。

这版适合上架，原因很直接：

- 小尺寸识别稳定，主体只有一个碗和一个勾形符号
- 厨房感明确，和现有绿色主题一致
- `Cooklist` 的“list”通过勾形蒸汽表达，记忆点更强

源文件：

- `docs/icon-concepts/cooklist-icon-01-check-bowl.svg`

拆层文件：

- `docs/icon-concepts/cooklist-icon-01-background.svg`
- `docs/icon-concepts/cooklist-icon-01-foreground.svg`
- `docs/icon-concepts/cooklist-icon-01-accent.svg`

放进 Icon Composer 时，建议按三层处理：

1. Background
   - 使用 `cooklist-icon-01-background.svg`
   - 只保留外层绿色圆角底板
2. Foreground
   - 使用 `cooklist-icon-01-foreground.svg`
   - 象牙白碗体 + 金色碗沿
3. Accent
   - 使用 `cooklist-icon-01-accent.svg`
   - 勾形蒸汽

Light / Dark / Tinted 建议：

- Light：保持当前配色，绿色偏柔和，金色偏暖
- Dark：底板压深到 `#183A2C` 附近，碗体提亮，勾形保持暖金
- Tinted：只保留单色轮廓关系，优先保留碗体外轮廓和勾形蒸汽，去掉渐变与高光

导出建议：

- 1024 x 1024
- 四周安全边距保持 77 px
- 不加文字
- 不加复杂食材或多余器具
- 小尺寸预览重点看 64 px 和 32 px
