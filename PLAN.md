# 菜品图片统一裁剪与透明 PNG 上传方案

## Summary
在 iOS App 中实现两条图片入口：`拍照上传` 和 `相册上传`。两条路径都收敛到同一套规则：固定比例取景器裁出有效区域，本地执行去背景，导出统一尺寸透明底 `PNG`，用户确认保存菜品时再同步上传到 R2，数据库保存可访问图片地址。

核心约束：
- 拍照页取景器比例、相册裁剪页取景器比例、菜单展示比例完全一致
- 客户端只上传处理后的成品 `PNG`
- 原图和中间文件只在本地临时缓存，上传成功后立即清理
- 后端负责签发上传地址，客户端负责拼接最终访问地址并随菜品保存

## Key Changes
### iOS 端图片链路
- 新增统一图片规格常量 `DishImageSpec`：
  - `viewportAspectRatio`：拍照、裁剪、展示共用同一比例，建议 `4:3`
  - `outputPixelSize`：统一输出尺寸，例如 `1200x900`
  - `displayAspectRatio`：菜单卡片图片容器使用同一比例
  - `mimeType`：`image/png`
- 新增图片草稿状态 `DishDraftImageState`：
  - `empty`
  - `capturing`
  - `cropping`
  - `processing`
  - `ready(previewImage, pngFileURL, publicURL)`
  - `failed(message)`
- 新增本地协调器 `DishImageCoordinator`，负责：
  - 原图导入
  - 临时文件路径分配
  - 裁剪参数保存
  - 去背景处理
  - PNG 导出
  - 上传前缓存管理
  - 上传成功后的清理

### 拍照流程
- 新增自定义拍照页 `DishCameraCaptureView`
- 使用 `AVCaptureSession + AVCapturePhotoOutput`
- 页面中央叠加固定比例取景器遮罩：
  - 可视区之外做半透明遮罩
  - 拍照按钮、关闭按钮、闪光灯切换放在安全区内
- 拍照结果处理：
  1. 获取原始照片
  2. 将预览层坐标系中的取景器区域映射到照片像素坐标
  3. 直接裁出取景器范围作为有效图
  4. 把裁后的图送入去背景流水线
  5. 生成透明底 PNG 预览
- 拍照页不再提供二次自由裁剪，拍摄时的取景器就是最终裁切规则

### 相册流程
- 使用 `PhotosPicker` 选择图片
- 选中后进入自定义裁剪页 `DishPhotoCropView`
- 裁剪页与拍照页保持同一取景器比例和视觉样式
- 用户交互：
  - 拖拽图片调整主体位置
  - 双指缩放调整主体大小
  - 限制最小缩放，保证取景器始终被图片覆盖
- 确认裁剪后：
  1. 根据当前平移缩放参数裁出取景器区域
  2. 将裁后图送入去背景流水线
  3. 生成透明底 PNG 预览

### 图像处理
- 新增 `DishImagePipeline`
- 输入统一为“取景器范围内的裁后图”
- 处理步骤：
  1. 规范方向
  2. 缩放到输出规格附近，控制处理成本
  3. 使用 `Vision` 的 `VNGenerateForegroundInstanceMaskRequest` 做主体提取
  4. 用 mask 生成透明背景图
  5. 输出为统一尺寸透明底 `PNG`
- 本版不做主体有效性检查
- 处理失败时展示明确错误：读取失败、裁剪失败、去背景失败、导出失败

### 保存与上传
- 用户完成图片处理后只缓存本地成品，不立即上传
- 用户点击“保存菜品”时执行串行流程：
  1. 若菜品未创建，先创建菜品基础信息
  2. 请求后端上传票据
  3. 直接上传本地 `PNG` 成品到 R2
  4. 基于 `image_key` 拼接公开访问地址
  5. 将图片地址或对应字段写入菜品记录
  6. 删除本地原图与全部中间文件
- 如果图片上传失败：
  - 菜品基础信息保留
  - 当前页面保留可重试状态
  - 用户可再次点击保存继续上传图片

### 展示层
- `MenuDishCard` 改为使用真实菜品图
- 图片容器比例与 `DishImageSpec.viewportAspectRatio` 一致
- 使用 `AsyncImage` 或等价远程图方案
- 内容模式固定为适配透明 PNG 的展示模式，避免拉伸变形
- 无图时回退到现有占位视觉

### 后端
- 保留“只签发上传地址、保存图片字段”的职责
- 调整图片 key 规则：
  - `"{kitchen_id}/{dish_id}.png"`
- `POST /api/v1/dishes/:dish_id/image_upload_url` 返回：
  - `upload_url`
  - `image_key`
  - `method`
  - `headers`
  - `expires_at`
- 上传目标 content type 固定 `image/png`
- 菜品更新接口支持写入图片字段：
  - 如果当前库里存的是 `image_key`，客户端存 `image_key`
  - 如果你准备改成图片完整地址，新增 `image_url` 字段后再写完整地址
- 推荐继续存 `image_key`，读取时由客户端拼接访问地址，数据更稳定

## Public Interfaces
- iOS 新增类型：
  - `DishImageSpec`
  - `DishDraftImageState`
  - `DishImageCoordinator`
  - `DishImagePipeline`
  - `DishImageUploadTicket`
- iOS API 新增响应模型：
  - `RequestDishImageUploadURLResponse { uploadURL, imageKey, method, headers, expiresAt }`
- 后端接口保持：
  - `POST /api/v1/dishes/:dish_id/image_upload_url`
  - `PATCH /api/v1/dishes/:dish_id`
- 数据字段推荐：
  - DB 继续保存 `image_key`
  - App 侧增加 `publicImageURL(baseURL:)` 计算属性用于展示

## Test Plan
- 单测
  - 裁剪参数能正确从取景器映射到原图像素坐标
  - 拍照页与相册裁剪页输出尺寸一致
  - 去背景后输出文件格式为透明底 PNG
  - 上传成功后原图、裁剪图、mask、导出图全部删除
- UI 测试
  - 相册入口可进入裁剪页，拖拽缩放后生成预览
  - 拍照入口可见固定比例取景器，拍照后直接生成预览
  - 保存菜品时带图上传成功，菜单卡片显示真实图片
  - 上传失败时菜品文本保留，图片可重试上传
- 端到端
  - R2 中只有处理后的成品 PNG
  - 数据库存储的图片字段可还原出可访问地址
  - 拍照、裁剪、展示三处比例一致，视觉无变形

## Assumptions
- 最低系统版本 `iOS 17.6`，可直接使用 `PhotosPicker` 和 `Vision`
- 取景器比例采用 `4:3`
- 输出尺寸采用 `1200x900`
- 数据库存 `image_key`，客户端通过配置的 `IMAGE_BASE_URL` 拼接访问地址
- 去背景能力完全在端侧完成，后端不参与任何图片后处理

先按这套方案实现，优先顺序是：统一图片规格常量、拍照页、相册裁剪页、本地去背景流水线、保存时上传、菜单展示接入真实图片。
