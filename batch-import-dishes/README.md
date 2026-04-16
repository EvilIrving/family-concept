# 批量导入菜品

这个目录用于一次性把历史菜品导入现有后端，不新增任何接口，直接复用 `POST /api/v1/kitchens/:id/dishes`。

## 目录约定

把图片放到 `images/` 目录。

把清单放到 `recipes.json`。

脚本配置放到 `config.local.json`。

## recipes.json 格式

```json
[
  {
    "name": "番茄炒蛋",
    "ingredients": ["番茄", "鸡蛋", "盐"],
    "category": "家常"
  },
  {
    "name": "红烧排骨",
    "image": "红烧排骨.jpg",
    "ingredients": ["排骨", "冰糖", "生抽"]
  }
]
```

说明：

`name` 必填。

`ingredients` 选填，必须是字符串数组。

`category` 选填，没填就走 `config.local.json` 里的 `defaultCategory`。

`image` 选填，没填时脚本会直接按 `name` 去 `images/` 目录里找同名图片，支持 `.png`、`.jpg`、`.jpeg`、`.webp`、`.heic`。

## config.local.json 格式

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

## 执行

先演练一次，只检查 JSON 和图片匹配：

```bash
node batch-import-dishes/import-dishes.mjs --config batch-import-dishes/config.local.json
```

如果你想先只跑校验，把 `config.local.json` 里的 `dryRun` 改成 `true`。

确认无误后，再把 `dryRun` 改成 `false` 正式导入。
