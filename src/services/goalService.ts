import * as SQLite from 'expo-sqlite';
import { Goal, GoalStatus } from '@/src/lib/types';
import { generateId } from '@/src/lib/utils';

function getDb() {
  return SQLite.openDatabaseSync('finanzas.db');
}

function rowToGoal(row: any): Goal {
  return {
    id: row.id,
    name: row.name,
    description: row.description ?? undefined,
    targetAmount: row.target_amount,
    currentAmount: row.current_amount,
    targetDate: row.target_date ?? undefined,
    priority: row.priority,
    color: row.color,
    icon: row.icon ?? undefined,
    status: row.status as GoalStatus,
    createdAt: row.created_at,
  };
}

export const goalService = {
  getAll(): Goal[] {
    const db = getDb();
    const rows = db.getAllSync<any>(
      "SELECT * FROM goals WHERE status != 'completed' ORDER BY priority ASC, created_at DESC",
      []
    );
    return rows.map(rowToGoal);
  },

  getById(id: string): Goal | null {
    const db = getDb();
    const row = db.getFirstSync<any>('SELECT * FROM goals WHERE id = ?', [id]);
    return row ? rowToGoal(row) : null;
  },

  create(data: Omit<Goal, 'id' | 'createdAt' | 'currentAmount'>): Goal {
    const db = getDb();
    const id = generateId();
    const createdAt = new Date().toISOString();
    db.runSync(
      'INSERT INTO goals (id, name, description, target_amount, current_amount, target_date, priority, color, icon, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [id, data.name, data.description ?? null, data.targetAmount, 0, data.targetDate ?? null, data.priority, data.color, data.icon ?? null, data.status, createdAt]
    );
    return { ...data, id, currentAmount: 0, createdAt };
  },

  update(id: string, data: Partial<Goal>): void {
    const db = getDb();
    const fields: string[] = [];
    const values: any[] = [];
    if (data.name !== undefined) { fields.push('name = ?'); values.push(data.name); }
    if (data.description !== undefined) { fields.push('description = ?'); values.push(data.description); }
    if (data.targetAmount !== undefined) { fields.push('target_amount = ?'); values.push(data.targetAmount); }
    if (data.currentAmount !== undefined) { fields.push('current_amount = ?'); values.push(data.currentAmount); }
    if (data.targetDate !== undefined) { fields.push('target_date = ?'); values.push(data.targetDate); }
    if (data.priority !== undefined) { fields.push('priority = ?'); values.push(data.priority); }
    if (data.color !== undefined) { fields.push('color = ?'); values.push(data.color); }
    if (data.icon !== undefined) { fields.push('icon = ?'); values.push(data.icon); }
    if (data.status !== undefined) { fields.push('status = ?'); values.push(data.status); }
    if (fields.length === 0) return;
    values.push(id);
    db.runSync(`UPDATE goals SET ${fields.join(', ')} WHERE id = ?`, values);
  },

  addContribution(id: string, amount: number): Goal | null {
    const db = getDb();
    const goal = this.getById(id);
    if (!goal) return null;
    const newAmount = Math.min(goal.currentAmount + amount, goal.targetAmount);
    const newStatus: GoalStatus = newAmount >= goal.targetAmount ? 'completed' : 'active';
    db.runSync('UPDATE goals SET current_amount = ?, status = ? WHERE id = ?', [newAmount, newStatus, id]);
    return { ...goal, currentAmount: newAmount, status: newStatus };
  },
};
