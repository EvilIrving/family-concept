# 菜品图片链路增量实现计划

## Summary

本计划以当前仓库现状为事实源，目标是在现有 `AppStore + APIClient + Worker` 体系上，补齐菜品图片的完整闭环：

- iOS 端支持两条入口：`拍照上传`、`相册上传`
- 两条入口统一收敛到同一套裁剪比例、同一套图片处理规格、同一套上传流程
- 客户端只上传处理后的成品图
- Worker 继续承担上传入口、权限校验、R2 写入和 `image_key` 持久化
- 菜单页使用真实菜品图展示，无图时保留现有占位视觉

本计划服务当前代码库，不引入新的身份模型，不拆分新的 Store 体系，不重做上传协议形态。

## Current Source Of Truth

当前代码中的既有约束如下：

- iOS 使用单一 `AppStore` 管理 `kitchen / members / dishes / orders`
- iOS 网络层由 `APIClient` 统一发起
- 领域模型使用 `Account / accountId / auth token`
- `Dish` 已有 `imageKey: String?`
- Worker 已提供图片相关接口：
  - `POST /api/v1/dishes/:dish_id/image_upload_url`
  - `PUT /api/v1/dishes/:dish_id/image`
- Worker 当前负责：
  - 校验 dish 存在性
  - 校验成员身份与角色权限
  - 接收客户端上传的图片流
  - 写入 R2
  - 更新 dishes 表中的 `image_key`

后续新增能力都基于这套结构演进。

## Goals

1. 统一拍照、相册裁剪、菜单展示的图片比例
2. 在 iOS 端完成裁剪、去背景、导出透明底 PNG
3. 保持 Worker 代理上传模式，避免新增直传 R2 的复杂协议
4. 保存菜品时完成图片上传与 `image_key` 写入
5. 菜单卡片接入真实图片展示

## Non-Goals

- 不重构为 `DishStore / OrderStore / MemberStore`
- 不改回 `device_id / devices` 模型
- 不把图片上传改成客户端直传 R2
- 不在本阶段引入图片编辑历史、滤镜、多图、草稿箱
- 不在本阶段实现服务端图片二次处理

## Architecture

### iOS 端职责

- 提供拍照页和相册裁剪页
- 统一管理菜品图片草稿状态
- 完成裁剪、方向修正、前景抠图、透明 PNG 导出
- 在用户点击“保存菜品”时上传处理后的成品图
- 上传成功后刷新本地 `Dish`

### Worker 端职责

- 提供上传入口
- 统一做权限校验
- 接收处理后的 PNG 数据流
- 将 PNG 写入 R2
- 将 `image_key` 写回 `dishes.image_key`

### 数据层职责

- `dishes` 表继续保留 `image_key`
- 客户端展示时基于 `image_key` 拼接可访问 URL
- 数据库存储继续只保存 key，不存本地临时文件信息

## Worker 上传链路

### 现有模型

当前仓库中的上传模型是“Worker 代理上传”，不是“客户端直传 R2”。

链路如下：

1. iOS 创建或更新菜品基础信息
2. iOS 调用 `POST /api/v1/dishes/:dish_id/image_upload_url`
3. Worker 校验：
   - 菜品存在
   - 菜品未归档
   - 当前用户属于该 kitchen
   - 当前用户角色为 `owner` 或 `admin`
4. Worker 返回上传信息
5. iOS 使用返回的上传入口，发起 `PUT` 上传成品图
6. Worker 接收请求体并写入 R2
7. Worker 更新 `dishes.image_key`
8. Worker 返回上传成功结果
9. iOS 刷新本地 dish 数据并展示真实图片

### 推荐保留的协议形态

本阶段继续保留两段式接口：

- `POST /api/v1/dishes/:dish_id/image_upload_url`
- `PUT /api/v1/dishes/:dish_id/image`

保留原因：

- 兼容当前代码结构
- 权限校验集中在 Worker
- 客户端实现简单
- 后续若需要加入限流、审计、内容检查，也有统一入口

### 本阶段要调整的点

当前 Worker 使用 `.jpg` 和 `image/jpeg`。本计划统一改为透明底 PNG：

- `image_key` 规则改为 `"{kitchen_id}/{dish_id}.png"`
- `PUT /api/v1/dishes/:dish_id/image` 写入 R2 时使用 `contentType: image/png`
- `POST /image_upload_url` 返回的 `image_key` 同步变为 `.png`

### 接口约定

#### `POST /api/v1/dishes/:dish_id/image_upload_url`

职责：

- 校验权限
- 返回当前 dish 的上传入口和目标 key

建议响应：

```json
{
  "upload_url": "/api/v1/dishes/<dish_id>/image",
  "image_key": "<kitchen_id>/<dish_id>.png",
  "method": "PUT",
  "content_type": "image/png"
}
```

说明：

- `upload_url` 继续指向 Worker 自己的上传入口
- `method` 和 `content_type` 返回给 iOS，便于客户端统一上传实现

#### `PUT /api/v1/dishes/:dish_id/image`

职责：

- 校验权限
- 接收 PNG 请求体
- 写入 R2
- 更新 dishes 表中的 `image_key`

建议返回：

```json
{
  "ok": true,
  "image_key": "<kitchen_id>/<dish_id>.png"
}
```

### Worker 实现要求

#### 路由层

- 保持当前 `worker/src/routes/dishes.ts` 作为图片接口入口
- 上传前校验 dish、member、role
- 对归档菜品返回 `404`
- 对成员权限不足返回 `403`

#### R2 写入

- key 统一使用 `"{kitchen_id}/{dish_id}.png"`
- `httpMetadata.contentType` 固定为 `image/png`

#### DB 更新

- R2 写入成功后再更新 `dishes.image_key`
- 数据库更新失败时返回错误，避免客户端误判上传完成

#### 错误语义

- 菜品不存在：`404`
- 当前用户不是 kitchen 成员：`403`
- 当前用户是 member 无管理权限：`403`
- R2 写入失败：`500`
- DB 更新失败：`500`

## iOS 图片实现

### 总体原则

- 拍照入口和相册入口共用同一套图片规格
- 最终上传物统一为透明底 PNG
- 原图、中间图、导出图只在本地临时目录保留
- 用户点击“保存菜品”时再上传
- 上传成功后清理临时文件

### 图片规格

新增统一规格类型 `DishImageSpec`：

- `viewportAspectRatio`: 拍照、裁剪、展示共用比例，先采用 `4:3`
- `outputPixelSize`: 导出尺寸，先采用 `1200x900`
- `mimeType`: `image/png`
- `fileExtension`: `png`

图片相关页面和菜单卡片都以这组常量为准。

### 本地图片状态

新增 `DishDraftImageState`，用于新增菜品 sheet 内部管理图片流程：

- `empty`
- `capturing`
- `cropping`
- `processing`
- `ready(previewImage, pngFileURL)`
- `uploading`
- `failed(message)`

这个状态先作为新增菜品页面的本地 `@State` 或图片协调对象状态存在，不单独拆 Store。

### 图片协调器

新增 `DishImageCoordinator`，负责串联端侧图片流程：

- 导入原图
- 分配临时文件路径
- 保存裁剪参数
- 调用去背景流水线
- 输出 PNG 文件
- 上传前读取最终文件
- 上传完成后清理临时文件

### 相册上传实现

#### 入口

- 在新增菜品 sheet 中加入“从相册选择”
- 使用 `PhotosPicker`

#### 交互流程

1. 用户从相册选图
2. 进入自定义裁剪页 `DishPhotoCropView`
3. 裁剪页提供固定比例取景器
4. 用户可拖拽图片调整主体位置
5. 用户可双指缩放调整主体大小
6. 限制最小缩放，确保取景器始终被图片完整覆盖
7. 用户确认后导出取景器范围图像
8. 将裁后图送入去背景流水线
9. 输出透明 PNG 预览

#### 裁剪页要求

- 取景器比例与拍照页完全一致
- 非取景器区域使用半透明遮罩
- 顶部保留关闭与确认动作
- 视觉风格遵循现有 `AppTheme`

### 拍照上传实现

#### 入口

- 在新增菜品 sheet 中加入“拍照上传”
- 进入自定义拍照页 `DishCameraCaptureView`

#### 拍照页实现

- 使用 `AVCaptureSession + AVCapturePhotoOutput`
- 页面中央叠加固定比例取景器
- 取景器外区域使用半透明遮罩
- 操作按钮放在安全区内，包含：
  - 关闭
  - 拍照
  - 闪光灯切换

#### 拍照后处理

1. 获取原始照片数据
2. 统一处理方向信息
3. 将取景器区域从预览层坐标映射到原始图像像素坐标
4. 直接裁出取景器范围
5. 将裁后图送入去背景流水线
6. 生成透明 PNG 预览

#### 交互约束

- 拍照流程采用“拍时即裁”
- 拍照后不进入自由裁剪页
- 拍照页取景器就是最终裁剪规则

### 去背景与导出

新增 `DishImagePipeline`，输入统一为“已经裁好的取景器图像”。

处理步骤：

1. 修正图片方向
2. 将输入图缩放到目标处理尺寸附近
3. 使用 `Vision` 的 `VNGenerateForegroundInstanceMaskRequest` 提取主体
4. 基于 mask 生成透明背景图
5. 缩放并导出为统一尺寸 PNG

失败时给出明确错误：

- 图片读取失败
- 裁剪失败
- 去背景失败
- 导出失败

### 保存菜品时的上传逻辑

当前新增菜品流程在 `MenuView` 中调用 `store.addDish(...)`。图片能力接入后，保存流程调整为串行步骤：

1. 先创建菜品基础信息
2. 若当前没有图片，流程结束
3. 若当前有处理完成的 PNG：
   - 调用 `POST /api/v1/dishes/:dish_id/image_upload_url`
   - 按返回的 `upload_url` 发起 `PUT`
   - 上传本地 PNG 成品
4. 上传成功后：
   - 清理临时文件
   - 重新拉取 dishes，或直接用返回值更新对应 dish 的 `imageKey`
5. 若上传失败：
   - 保留已创建的菜品基础信息
   - 保留页面上的本地图片状态
   - 允许用户再次点击保存重试上传

### APIClient 扩展

iOS 端新增接口模型：

```swift
struct DishImageUploadTicket: Decodable {
    let uploadURL: String
    let imageKey: String
    let method: String
    let contentType: String
}
```

新增 API：

- `requestDishImageUploadURL(dishID:authToken:)`
- `uploadDishImage(uploadURL:fileURL:contentType:authToken:)`

说明：

- 上传请求仍然走 Worker 接口
- 若 `upload_url` 为相对路径，按当前 `baseURL` 拼接成绝对地址后再发请求

## 展示层接入

### Dish 模型

继续使用现有 `imageKey: String?`，不新增 `imageURL` 持久化字段。

可以增加便捷计算属性：

```swift
func publicImageURL(baseURL: String) -> URL?
```

用于菜单展示层拼接访问地址。

### MenuDishCard

当前 `MenuDishCard` 使用系统图占位。接入真实图片后改为：

- 有 `imageKey` 时展示远程图片
- 无图时保留现有渐变占位和图标
- 图片容器比例与 `DishImageSpec.viewportAspectRatio` 一致
- 透明 PNG 使用适合主体展示的内容模式，避免拉伸

### MenuView

`MenuView` 的新增菜品 sheet 需要补充：

- 图片入口区
- 图片预览区
- 处理状态展示
- 上传失败重试提示

这部分先在现有 `MenuView` 内实现，等流程稳定后再视体量拆分 `AddDishSheet`。

## File Plan

### Worker

- `worker/src/routes/dishes.ts`
  - 将 `.jpg` 改为 `.png`
  - 返回 `method`、`content_type`
  - 写入 R2 时使用 `image/png`

### iOS Models / Services

- `kitchen/kitchen/Models/Domain.swift`
  - 保持 `imageKey`
  - 视需要增加图片 URL 计算属性

- `kitchen/kitchen/Services/APIEndpoints.swift`
  - 新增图片上传 ticket 请求
  - 新增图片上传方法

### iOS UI / Views

- `kitchen/kitchen/Views/MenuView.swift`
  - 新增图片入口与保存串行流程

- `kitchen/kitchen/UI/Components/MenuDishCard.swift`
  - 支持远程图片展示

### iOS New Files

- `kitchen/kitchen/Models/DishImageSpec.swift`
- `kitchen/kitchen/Models/DishDraftImageState.swift`
- `kitchen/kitchen/Services/DishImagePipeline.swift`
- `kitchen/kitchen/Services/DishImageCoordinator.swift`
- `kitchen/kitchen/Views/DishCameraCaptureView.swift`
- `kitchen/kitchen/Views/DishPhotoCropView.swift`

## Delivery Phases

### Phase 1

文档与协议对齐

- 更新 `PLAN.md`
- 明确 Worker 代理上传链路
- 明确 PNG 规格

### Phase 2

Worker PNG 上传链路

- 上传 key 从 `.jpg` 改为 `.png`
- R2 metadata 改为 `image/png`
- 返回 upload ticket

### Phase 3

iOS 相册链路

- `PhotosPicker`
- 自定义裁剪页
- 去背景与 PNG 导出
- 保存时上传

### Phase 4

菜单真实图片展示

- `MenuDishCard` 展示远程图
- `MenuView` 接入预览和上传结果

### Phase 5

iOS 拍照链路

- 自定义拍照页
- 固定比例取景器
- 拍后直接裁切

### Phase 6

测试与体验打磨

- 异常处理
- 文件清理
- UI 调整

## Test Plan

### Worker

- `POST /image_upload_url` 返回 `.png` key
- `PUT /image` 能写入 PNG 到 R2
- 上传成功后 dishes 表的 `image_key` 被更新
- member 角色上传返回 `403`
- 已归档菜品上传返回 `404`

### iOS 单测

- 裁剪参数到原图坐标映射正确
- 相册裁剪输出尺寸正确
- 拍照裁切输出比例正确
- 去背景后导出文件格式为透明 PNG
- 上传成功后临时文件被清理

### iOS UI 测试

- 相册入口进入裁剪页并生成预览
- 拍照入口显示固定比例取景器
- 保存菜品时可上传图片
- 上传失败后可再次重试
- 菜单卡片成功显示真实图片

## Implementation Order

1. Worker 图片链路升级到 PNG
2. iOS `APIClient` 增加 upload ticket 和上传方法
3. iOS 相册裁剪与图片处理
4. 保存菜品时上传图片
5. 菜单真实图片展示
6. iOS 拍照页
7. 测试与细节打磨

先完成相册链路和菜单展示闭环，再接拍照链路。这条顺序最稳，验证成本最低，和现有体系最一致。
