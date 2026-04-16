#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';

const IMAGE_EXTENSIONS = ['.png', '.jpg', '.jpeg', '.webp', '.heic'];

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 1) {
    const current = argv[i];
    if (!current.startsWith('--')) continue;
    const key = current.slice(2);
    const next = argv[i + 1];
    if (!next || next.startsWith('--')) {
      args[key] = 'true';
      continue;
    }
    args[key] = next;
    i += 1;
  }
  return args;
}

function printUsage() {
  console.log(`
用法:
  node batch-import-dishes/import-dishes.mjs --config batch-import-dishes/config.local.json

配置示例:
  {
    "baseUrl": "https://api.kitchen.onecat.dev",
    "userName": "your_user_name",
    "password": "your_password",
    "kitchenId": "your_kitchen_id",
    "manifestPath": "./batch-import-dishes/recipes.json",
    "imagesDir": "./batch-import-dishes/images",
    "defaultCategory": "家常",
    "continueOnError": true,
    "dryRun": false
  }
`.trim());
}

async function readJson(filePath) {
  const content = await fs.readFile(filePath, 'utf8');
  return JSON.parse(content);
}

function normalizeIngredients(ingredients, dishName) {
  if (ingredients === undefined) return [];
  if (!Array.isArray(ingredients)) {
    throw new Error(`"${dishName}" 的 ingredients 必须是数组`);
  }

  return ingredients
    .map((item) => String(item).trim())
    .filter(Boolean);
}

async function fileExists(filePath) {
  try {
    await fs.access(filePath);
    return true;
  } catch {
    return false;
  }
}

async function resolveImagePath(imagesDir, imageNameOrDishName) {
  const rawName = imageNameOrDishName.trim();
  const ext = path.extname(rawName).toLowerCase();

  if (ext) {
    const exactPath = path.join(imagesDir, rawName);
    if (await fileExists(exactPath)) return exactPath;
  }

  for (const candidateExt of IMAGE_EXTENSIONS) {
    const candidatePath = path.join(imagesDir, `${rawName}${candidateExt}`);
    if (await fileExists(candidatePath)) return candidatePath;
  }

  throw new Error(`找不到图片文件: ${rawName}`);
}

async function login(baseUrl, userName, password) {
  const response = await fetch(`${baseUrl}/api/v1/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      user_name: userName,
      password,
    }),
  });

  const payload = await response.json().catch(() => null);
  if (!response.ok) {
    const message = payload?.message ?? `登录失败 (${response.status})`;
    throw new Error(message);
  }
  if (!payload?.token) {
    throw new Error('登录成功，但未返回 token');
  }

  return payload.token;
}

async function createDish(baseUrl, kitchenId, token, dish, dryRun) {
  if (dryRun) return { ok: true, dryRun: true };

  const form = new FormData();
  form.set('name', dish.name);
  form.set('category', dish.category);
  for (const ingredient of dish.ingredients) {
    form.append('ingredients[]', ingredient);
  }

  const imageBuffer = await fs.readFile(dish.imagePath);
  const imageBlob = new Blob([imageBuffer], { type: 'image/png' });
  form.set('image', imageBlob, path.basename(dish.imagePath));

  const response = await fetch(`${baseUrl}/api/v1/kitchens/${kitchenId}/dishes`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
    },
    body: form,
  });

  const payload = await response.json().catch(() => null);
  if (!response.ok) {
    const message = payload?.message ?? `创建失败 (${response.status})`;
    throw new Error(message);
  }

  return payload;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help === 'true' || !args.config) {
    printUsage();
    process.exit(args.config ? 0 : 1);
  }

  const configPath = path.resolve(process.cwd(), args.config);
  const config = await readJson(configPath);
  const baseUrl = String(config.baseUrl ?? '').replace(/\/+$/, '');
  const userName = String(config.userName ?? '').trim();
  const password = String(config.password ?? '');
  const kitchenId = String(config.kitchenId ?? '').trim();
  const manifestPath = path.resolve(path.dirname(configPath), config.manifestPath ?? './recipes.json');
  const imagesDir = path.resolve(path.dirname(configPath), config.imagesDir ?? './images');
  const defaultCategory = String(config.defaultCategory ?? '家常').trim() || '家常';
  const continueOnError = Boolean(config.continueOnError ?? true);
  const dryRun = Boolean(config.dryRun ?? false);

  if (!baseUrl || !userName || !password || !kitchenId) {
    throw new Error('config 缺少 baseUrl、userName、password 或 kitchenId');
  }

  const manifest = await readJson(manifestPath);
  if (!Array.isArray(manifest)) {
    throw new Error('recipes.json 必须是数组');
  }

  const token = await login(baseUrl, userName, password);
  console.log(`登录成功，开始导入 ${manifest.length} 条记录`);

  let successCount = 0;
  let failureCount = 0;

  for (const rawItem of manifest) {
    const name = String(rawItem?.name ?? '').trim();
    const imageName = String(rawItem?.image ?? name).trim();
    const category = String(rawItem?.category ?? defaultCategory).trim() || defaultCategory;

    if (!name) {
      failureCount += 1;
      console.error('[跳过] 缺少 name');
      if (!continueOnError) process.exit(1);
      continue;
    }

    try {
      const ingredients = normalizeIngredients(rawItem?.ingredients, name);
      const imagePath = await resolveImagePath(imagesDir, imageName);
      const result = await createDish(
        baseUrl,
        kitchenId,
        token,
        { name, category, ingredients, imagePath },
        dryRun
      );

      successCount += 1;
      if (dryRun) {
        console.log(`[演练成功] ${name} <- ${path.basename(imagePath)}`);
      } else {
        console.log(`[导入成功] ${name} ${result?.id ? `(${result.id})` : ''}`.trim());
      }
    } catch (error) {
      failureCount += 1;
      const message = error instanceof Error ? error.message : String(error);
      console.error(`[导入失败] ${name}: ${message}`);
      if (!continueOnError) process.exit(1);
    }
  }

  console.log(`导入结束: 成功 ${successCount} 条, 失败 ${failureCount} 条`);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
