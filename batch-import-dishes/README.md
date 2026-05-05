# 批量导入菜品

在本目录准备 `recipes.json` 与 `images/`，用脚本逐条调用 **`POST /api/v1/kitchens/:id/dishes`**（multipart，与 App 加菜一致），不新增 Worker 接口。

脚本会先 **`POST /api/v1/auth/login`** 拿 token，再导入。

## 环境

- Node **18+**（使用全局 `fetch` / `FormData` / `Blob`）
- 在**仓库根目录**执行下方命令（脚本内路径示例也按根目录写法）

## 快速开始

1. 复制示例配置并填入真实值（**不要提交** `config.local.json`）：

   ```bash
   cp batch-import-dishes/config.local.example.json batch-import-dishes/config.local.json
   ```

2. 按需复制或编写清单（可参考 `recipes.example.json`）：

   ```bash
   cp batch-import-dishes/recipes.example.json batch-import-dishes/recipes.json
   ```

3. 把菜品图片放进 `batch-import-dishes/images/`（见下文匹配规则）。

4. 先试跑：**每条菜都必须能解析到本地图片**，否则该行会失败。

## 目录约定

| 路径 | 说明 |
|------|------|
| `images/` | 菜品图片目录，相对 **配置文件所在目录** 解析 |
| `recipes.json` | 清单路径由配置项 `manifestPath` 指定，同样相对配置文件目录 |
| `config.local.json` | 本地配置（仅本机保留，可参考 `config.local.example.json`） |

## `recipes.json` 格式

```json
[
  {
    "name": "番茄炒蛋",
    "ingredients": ["番茄", "鸡蛋", "盐"],
    "category": "家常"
  },
  {
    "name": "清蒸鲈鱼",
    "image": "清蒸鲈鱼.webp",
    "ingredients": ["鲈鱼", "姜", "葱", "蒸鱼豉油"]
  }
]
```

字段说明：

- **`name`**：必填；菜名。
- **`ingredients`**：选填；字符串数组；缺省或空数组则不上传配料。
- **`category`**：选填；缺省使用配置里的 **`defaultCategory`**。
- **`image`**：选填；磁盘上的文件名（可带后缀）。不写时脚本用 **`name`** 当作基名去 `images/` 里查找。

图片解析规则：`images/` 下存在 `image` 字面名，或无后缀时依次尝试后缀 **`.png`、`.jpg`、`.jpeg`、`.webp`、`.heic`**。每一条记录**都必须**解析到可读图片，否则本条报错。

## `config.local.json` 格式

路径类字段 **`manifestPath`、`imagesDir` 均以配置文件所在目录为基准**（即 `batch-import-dishes/`），与终端当前目录无关。

```json
{
  "baseUrl": "https://api.kitchen.onecat.dev",
  "userName": "your_user_name",
  "password": "your_password",
  "kitchenId": "your_kitchen_id",
  "manifestPath": "./recipes.json",
  "imagesDir": "./images",
  "defaultCategory": "家常",
  "continueOnError": true,
  "dryRun": false
}
```

- **`continueOnError`**：默认 `true`；单条失败时是否继续后面条目。
- **`dryRun`**：`true` 时不发创建请求，只做登录 + 校验 JSON 与图片能否配对；仍会请求登录接口。

## 执行

查看用法：

```bash
node batch-import-dishes/import-dishes.mjs --help
```

从仓库根目录执行（路径与脚本内 `--config` 一致）：

```bash
node batch-import-dishes/import-dishes.mjs --config batch-import-dishes/config.local.json
```

建议流程：先把 `dryRun` 设为 `true` 确认清单与图片；再改回 `false` 正式导入。
