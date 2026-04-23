import type { Route } from '../types';
import { json, badRequest, conflict } from '../router';
import { withAuth } from '../middleware/auth';
import { withRole } from '../middleware/role';
import {
  createDish,
  getDishForKitchen,
  updateDish,
  archiveDish,
  listByKitchen,
  findById,
  DishLimitExceededError,
} from '../services/dish-service';

export const dishRoutes: Route[] = [
  // GET /kitchens/:id/dishes
  {
    method: 'GET',
    pattern: /^\/api\/v1\/kitchens\/(?<id>[^/]+)\/dishes$/,
    handler: withAuth(
      withRole(['owner', 'admin', 'member'])(async (_req, env, ctx) => {
        const dishes = await listByKitchen(env.DB, ctx.kitchen!.id);
        return json(dishes);
      })
    ),
  },

  // POST /kitchens/:id/dishes
  {
    method: 'POST',
    pattern: /^\/api\/v1\/kitchens\/(?<id>[^/]+)\/dishes$/,
    handler: withAuth(
      withRole(['owner', 'admin'])(async (req, env, ctx) => {
        const contentType = req.headers.get('content-type') ?? '';

        let name: string | undefined
        let category: string | undefined
        let ingredients: unknown[] | undefined
        let imageBytes: ArrayBuffer | undefined
        let imageContentType: string | undefined

        if (contentType.includes('multipart/form-data')) {
          const form = await req.formData();
          name = form.get('name')?.toString().trim();
          category = form.get('category')?.toString().trim();

          const ingredientValues = form
            .getAll('ingredients[]')
            .map(value => value.toString().trim())
            .filter(Boolean);
          if (ingredientValues.length > 0) ingredients = ingredientValues;

          const imageFile = form.get('image');
          if (imageFile instanceof File) {
            imageBytes = await imageFile.arrayBuffer();
            if (imageBytes.byteLength === 0) return badRequest('图片内容为空');
            imageContentType = imageFile.type || 'application/octet-stream';
          }
        } else {
          const body = await req.json<{ name?: string; category?: string; ingredients?: unknown[] }>();
          name = body?.name?.trim();
          category = body?.category?.trim();
          if (body.ingredients !== undefined) {
            if (!Array.isArray(body.ingredients)) return badRequest('ingredients 格式错误');
            ingredients = body.ingredients;
          }
        }

        if (!name || !category) return badRequest('name 和 category 为必填项');

        const dishID = crypto.randomUUID();
        const imageKey = imageBytes ? `${ctx.kitchen!.id}/${dishID}.png` : null;

        try {
          if (imageBytes && imageKey) {
            await env.ASSETS.put(imageKey, imageBytes, {
              httpMetadata: { contentType: imageContentType ?? 'application/octet-stream' },
            });
          }

          const dish = await createDish(
            env.DB,
            ctx.kitchen!.id,
            ctx.account.id,
            name,
            category,
            ingredients,
            { id: dishID, imageKey }
          );
          return json(dish, { status: 201 });
        } catch (error) {
          if (imageKey) {
            try {
              await env.ASSETS.delete(imageKey);
            } catch {}
          }
          if (error instanceof DishLimitExceededError) {
            return json(
              {
                code: 'dish_limit_exceeded',
                message: `已达菜品上限（${error.limit}）`,
                limit: error.limit,
                plan_code: error.planCode,
              },
              { status: 402 }
            );
          }
          const message = error instanceof Error ? error.message : String(error);
          if (message.includes('UNIQUE constraint failed: dishes.kitchen_id, dishes.name')) {
            return conflict('菜名已存在');
          }
          throw error;
        }
      })
    ),
  },

  // PATCH /dishes/:dish_id
  {
    method: 'PATCH',
    pattern: /^\/api\/v1\/dishes\/(?<dish_id>[^/]+)$/,
    handler: withAuth(async (req, env, ctx, params) => {
      const dish = await findById(env.DB, params.dish_id);
      if (!dish || dish.archived_at !== null) return json({ message: '菜品不存在' }, { status: 404 });

      // Check role in dish's kitchen
      const { findByKitchenAndAccount } = await import('../db/members');
      const { findById: findKitchen } = await import('../db/kitchens');

      const kitchen = await findKitchen(env.DB, dish.kitchen_id);
      if (!kitchen) return json({ message: 'Kitchen 不存在' }, { status: 404 });

      const member = await findByKitchenAndAccount(env.DB, dish.kitchen_id, ctx.account.id);
      if (!member) return json({ message: '你不是该 kitchen 的成员' }, { status: 403 });
      if (member.role === 'member') return json({ message: '权限不足' }, { status: 403 });

      const body = await req.json<{ name?: string; category?: string; ingredients?: unknown[]; image_key?: string }>();
      await updateDish(env.DB, dish.id, {
        name: body.name,
        category: body.category,
        ingredients_json: body.ingredients !== undefined ? JSON.stringify(body.ingredients) : undefined,
        image_key: body.image_key,
      });

      const updated = await findById(env.DB, dish.id);
      return json(updated);
    }),
  },

  // DELETE /dishes/:dish_id — 归档（软删除）
  {
    method: 'DELETE',
    pattern: /^\/api\/v1\/dishes\/(?<dish_id>[^/]+)$/,
    handler: withAuth(async (_req, env, ctx, params) => {
      const dish = await findById(env.DB, params.dish_id);
      if (!dish || dish.archived_at !== null) return json({ message: '菜品不存在' }, { status: 404 });

      const { findByKitchenAndAccount } = await import('../db/members');
      const member = await findByKitchenAndAccount(env.DB, dish.kitchen_id, ctx.account.id);
      if (!member) return json({ message: '你不是该 kitchen 的成员' }, { status: 403 });
      if (member.role === 'member') return json({ message: '权限不足' }, { status: 403 });

      await archiveDish(env.DB, dish.id);
      return json({ ok: true });
    }),
  },

  // POST /dishes/:dish_id/image_upload_url — 获取 R2 预签名上传 URL
  {
    method: 'POST',
    pattern: /^\/api\/v1\/dishes\/(?<dish_id>[^/]+)\/image_upload_url$/,
    handler: withAuth(async (_req, env, ctx, params) => {
      const dish = await findById(env.DB, params.dish_id);
      if (!dish || dish.archived_at !== null) return json({ message: '菜品不存在' }, { status: 404 });

      const { findByKitchenAndAccount } = await import('../db/members');
      const member = await findByKitchenAndAccount(env.DB, dish.kitchen_id, ctx.account.id);
      if (!member) return json({ message: '你不是该 kitchen 的成员' }, { status: 403 });
      if (member.role === 'member') return json({ message: '权限不足' }, { status: 403 });

      // Return the image_key and a worker-proxied upload URL
      // Client PUTs image to this URL, worker streams to R2
      const imageKey = `${dish.kitchen_id}/${dish.id}.png`;
      const uploadUrl = `/api/v1/dishes/${dish.id}/image`;

      return json({ upload_url: uploadUrl, image_key: imageKey, method: 'PUT', content_type: 'image/png' });
    }),
  },

  // PUT /dishes/:dish_id/image — 接收图片，存入 R2
  {
    method: 'PUT',
    pattern: /^\/api\/v1\/dishes\/(?<dish_id>[^/]+)\/image$/,
    handler: withAuth(async (req, env, ctx, params) => {
      const dish = await findById(env.DB, params.dish_id);
      if (!dish || dish.archived_at !== null) return json({ message: '菜品不存在' }, { status: 404 });

      const { findByKitchenAndAccount } = await import('../db/members');
      const member = await findByKitchenAndAccount(env.DB, dish.kitchen_id, ctx.account.id);
      if (!member) return json({ message: '你不是该 kitchen 的成员' }, { status: 403 });
      if (member.role === 'member') return json({ message: '权限不足' }, { status: 403 });

      const imageBytes = await req.arrayBuffer();
      if (imageBytes.byteLength === 0) {
        return json({ message: '图片内容为空' }, { status: 400 });
      }

      const imageKey = `${dish.kitchen_id}/${dish.id}.png`;
      await env.ASSETS.put(imageKey, imageBytes, {
        httpMetadata: { contentType: 'image/png' },
      });

      await updateDish(env.DB, dish.id, { image_key: imageKey });
      return json({ ok: true, image_key: imageKey });
    }),
  },
];
