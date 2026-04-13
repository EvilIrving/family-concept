import type { Route, RouteParams } from './types';

export function matchRoute(
  routes: Route[],
  method: string,
  pathname: string
): { handler: Route['handler']; params: RouteParams } | null {
  for (const route of routes) {
    if (route.method !== method && route.method !== '*') continue;
    const match = route.pattern.exec(pathname);
    if (match) {
      return { handler: route.handler, params: match.groups ?? {} };
    }
  }
  return null;
}

export function json(data: unknown, init?: ResponseInit): Response {
  return Response.json(data, {
    headers: { 'content-type': 'application/json; charset=utf-8' },
    ...init,
  });
}

export function notFound(): Response {
  return json({ message: '接口不存在' }, { status: 404 });
}

export function badRequest(message: string): Response {
  return json({ message }, { status: 400 });
}

export function forbidden(message = '权限不足'): Response {
  return json({ message }, { status: 403 });
}

export function unauthorized(message = '设备未注册'): Response {
  return json({ message }, { status: 401 });
}

export function conflict(message: string): Response {
  return json({ message }, { status: 409 });
}

export function serverError(message = '服务器内部错误'): Response {
  return json({ message }, { status: 500 });
}
