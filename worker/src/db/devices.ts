import type { DeviceRow } from '../types';

export async function insertDevice(
  db: D1Database,
  id: string,
  deviceId: string,
  displayName: string
): Promise<DeviceRow> {
  await db
    .prepare('INSERT INTO devices (id, device_id, display_name) VALUES (?, ?, ?)')
    .bind(id, deviceId, displayName)
    .run();
  return findById(db, id) as Promise<DeviceRow>;
}

export async function findByDeviceId(
  db: D1Database,
  deviceId: string
): Promise<DeviceRow | null> {
  return db
    .prepare('SELECT * FROM devices WHERE device_id = ?')
    .bind(deviceId)
    .first<DeviceRow>();
}

export async function findById(
  db: D1Database,
  id: string
): Promise<DeviceRow | null> {
  return db
    .prepare('SELECT * FROM devices WHERE id = ?')
    .bind(id)
    .first<DeviceRow>();
}
