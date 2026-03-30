import * as SQLite from 'expo-sqlite';
import { SalaryRule, SalaryBucket } from '@/src/lib/types';
import { generateId } from '@/src/lib/utils';

function getDb() {
  return SQLite.openDatabaseSync('finanzas.db');
}

function rowToSalaryRule(row: any): SalaryRule {
  return {
    id: row.id,
    name: row.name,
    payDay: row.pay_day,
    buckets: JSON.parse(row.buckets_json) as SalaryBucket[],
    isActive: Boolean(row.is_active),
  };
}

export const budgetService = {
  getSalaryRule(): SalaryRule | null {
    const db = getDb();
    const row = db.getFirstSync<any>('SELECT * FROM salary_rules WHERE is_active = 1 LIMIT 1', []);
    return row ? rowToSalaryRule(row) : null;
  },

  updateSalaryRule(id: string, buckets: SalaryBucket[]): void {
    const db = getDb();
    db.runSync('UPDATE salary_rules SET buckets_json = ? WHERE id = ?', [JSON.stringify(buckets), id]);
  },

  distributeIncome(amount: number): { bucket: SalaryBucket; distributedAmount: number }[] {
    const rule = this.getSalaryRule();
    if (!rule) return [];
    return rule.buckets.map((bucket) => ({
      bucket,
      distributedAmount: Math.round((amount * bucket.percentage) / 100),
    }));
  },

  getCategorySpending(year: number, month: number): { categoryId: string; total: number }[] {
    const db = getDb();
    const start = `${year}-${String(month).padStart(2, '0')}-01`;
    const end = `${year}-${String(month).padStart(2, '0')}-31`;
    return db.getAllSync<{ categoryId: string; total: number }>(
      "SELECT category_id as categoryId, SUM(amount) as total FROM transactions WHERE type = 'expense' AND date >= ? AND date <= ? GROUP BY category_id ORDER BY total DESC",
      [start, end]
    );
  },

  getMonthlyIncome(year: number, month: number): number {
    const db = getDb();
    const start = `${year}-${String(month).padStart(2, '0')}-01`;
    const end = `${year}-${String(month).padStart(2, '0')}-31`;
    const result = db.getFirstSync<{ total: number }>(
      "SELECT COALESCE(SUM(amount), 0) as total FROM transactions WHERE type = 'income' AND date >= ? AND date <= ?",
      [start, end]
    );
    return result?.total ?? 0;
  },

  getMonthlyExpense(year: number, month: number): number {
    const db = getDb();
    const start = `${year}-${String(month).padStart(2, '0')}-01`;
    const end = `${year}-${String(month).padStart(2, '0')}-31`;
    const result = db.getFirstSync<{ total: number }>(
      "SELECT COALESCE(SUM(amount), 0) as total FROM transactions WHERE type = 'expense' AND date >= ? AND date <= ?",
      [start, end]
    );
    return result?.total ?? 0;
  },
};
