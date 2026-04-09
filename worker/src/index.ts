export interface Env {
  DB: D1Database;
  ASSETS: R2Bucket;
  APP_ENV: string;
}

function json(data: unknown, init?: ResponseInit): Response {
  return Response.json(data, {
    headers: {
      "content-type": "application/json; charset=utf-8"
    },
    ...init
  });
}

function notFound(): Response {
  return json(
    {
      message: "接口不存在"
    },
    { status: 404 }
  );
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/api/v1/health") {
      const assetList = await env.ASSETS.list({ limit: 1 });

      return json({
        ok: true,
        env: env.APP_ENV,
        timestamp: new Date().toISOString(),
        r2Reachable: true,
        assetSampleCount: assetList.objects.length
      });
    }

    if (url.pathname === "/api/v1/bootstrap") {
      const result = await env.DB.prepare("select 'ok' as status").first<{ status: string }>();

      return json({
        apiVersion: "v1",
        database: result?.status ?? "unknown",
        storage: "ready"
      });
    }

    return notFound();
  }
};
