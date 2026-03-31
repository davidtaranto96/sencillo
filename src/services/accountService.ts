import * as SQLite from 'expo-sqlite';
import { Account, AccountType } from '@/src/lib/types';
import { generateId } from '@/src/lib/utils';

function getDb() {
  return SQLite.openDatabaseSync('finanzas.db');
}

function rowToAccount(row: any): Account {
  return {
    id: row.id,
    name: row.name,
    type: row.type as AccountType,
    currency: row.currency,
    balance: row.balance,
    entity: row.entity ?? undefined,
    color: row.color,
    icon: row.icon ?? undefined,
    isActive: Boolean(row.is_active),
    createdAt: row.created_at,
  };
}

export const accountService = {
  getAll(): Account[] {
    const db = getDb();
    const rows = db.getAllSync<any>('SELECT * FROM accounts WHERE is_active = 1 ORDER BY created_at ASC', []);
    return rows.map(rowToAccount);
  },

  getById(id: string): Account | null {
    const db = getDb();
    const row = db.getFirstSync<any>('SELECT * FROM accounts WHERE id = ?', [id]);
    return row ? rowToAccount(row) : null;
  },

  getTotalBalance(): number {
    const db = getDb();
    const result = db.getFirstSync<{ total: number }>(
      "SELECT COALESCE(SUM(balance), 0) as total FROM accounts WHERE is_active = 1 AND type != 'credit_card'",
      []
    );
    return result?.total ?? 0;
  },

  create(data: Omit<Account, 'id' | 'createdAt'>): Account {
    const db = getDb();
    const id = generateId();
    const createdAt = new Date().toISOString();
    db.runSync(
      'INSERT INTO accounts (id, name, type, currency, balance, entity, color, icon, is_active, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [id, data.name, data.type, data.currency, data.balance, data.entity ?? null, data.color, data.icon ?? null, data.isActive ? 1 : 0, createdAt]
    );
    return { ...data, id, createdAt };
  },

  update(id: string, data: Partial<Account>): void {
    const db = getDb();
    const fields: string[] = [];
    const values: any[] = [];
    if (data.name !== undefined) { fields.push('name = ?'); values.push(data.name); }
    if (data.type !== undefined) { fields.push('type = ?'); values.push(data.type); }
    if (data.balance !== undefined) { fields.push('balance = ?'); values.push(data.balance); }
    if (data.color !== undefined) { fields.push('color = ?'); values.push(data.color); }
    if (data.icon !== undefined) { fields.push('icon = ?'); values.push(data.icon); }
    if (data.entity !== undefined) { fields.push('entity = ?'); values.push(data.entity); }
    if (data.isActive !== undefined) { fields.push('is_active = ?'); values.push(data.isActive ? 1 : 0); }
    if (fields.length === 0) return;
    values.push(id);
    db.runSync(`UPDATE accounts SET ${fields.join(', ')} WHERE id = ?`, values);
  },

  updateBalance(id: string, newBalance: number): void {
    const db = getDb();
    db.runSync('UPDATE accounts SET balance = ? WHERE id = ?', [newBalance, id]);
  },

  delete(id: string): void {
    const db = getDb();
    db.runSync('UPDATE accounts SET is_active = 0 WHERE id = ?', [id]);
  },
};
