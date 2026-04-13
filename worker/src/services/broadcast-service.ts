import type { Env } from '../types';

export async function broadcast(
  env: Env,
  kitchenId: string,
  event: Record<string, unknown>
): Promise<void> {
  const id = env.KITCHEN_LIVE.idFromName(kitchenId);
  const stub = env.KITCHEN_LIVE.get(id);
  await stub.fetch('https://internal/broadcast', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(event),
  });
}
