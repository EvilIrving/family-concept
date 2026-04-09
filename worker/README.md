# worker

Cloudflare Worker 本地目录，负责 `Workers`、`D1`、`R2` 和 `/api/v1` 接口。

## 本地初始化

安装依赖：

```bash
pnpm install
```

登录 Cloudflare：

```bash
wrangler login
```

创建 D1 数据库后，把返回的 `database_id` 填入 `wrangler.jsonc`：

```bash
pnpm d1:create
```

创建 R2 bucket：

```bash
pnpm r2:create
```

本地启动 Worker：

```bash
pnpm dev
```

默认提供两个最小接口：

- `GET /api/v1/health`
- `GET /api/v1/bootstrap`
