import type { DeviceRow, KitchenRow, MemberRow } from '../types';
import { findByDeviceId, insertDevice } from '../db/devices';
import { createKitchen, joinByInviteCode } from './kitchen-service';

export async function onboardingComplete(
  db: D1Database,
  params: {
    mode: 'create' | 'join';
    device_id: string;
    display_name: string;
    kitchen_name?: string;
    invite_code?: string;
  }
): Promise<{ device: DeviceRow; kitchen: KitchenRow; member: MemberRow }> {
  const { mode, device_id, display_name, kitchen_name, invite_code } = params;

  // Upsert device
  let device = await findByDeviceId(db, device_id);
  if (!device) {
    device = await insertDevice(db, crypto.randomUUID(), device_id, display_name);
  }

  if (mode === 'create') {
    if (!kitchen_name) throw new Error('创建模式需要提供 kitchen_name');
    const { kitchen, member } = await createKitchen(db, device.id, kitchen_name);
    return { device, kitchen, member };
  } else {
    if (!invite_code) throw new Error('加入模式需要提供 invite_code');
    const { kitchen, member } = await joinByInviteCode(db, device.id, invite_code);
    return { device, kitchen, member };
  }
}
