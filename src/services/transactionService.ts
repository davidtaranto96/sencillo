import { Platform } from 'react-native';
import * as SQLite from 'expo-sqlite';
import { Transaction, TransactionType } from '@/src/lib/types';
import { generateId } from '@/src/lib/utils';
import { accountService } from './accountService';

function getDb() {
  if (Platform.OS === 'web') throw new Error('SQLite not available on web');
  return SQLite.openDatabaseSync('finanzas.db');
}

function rowToTransaction(row: any): Transaction {
  return {
    id: row.id,
    type: row.type as TransactionType,
    amount: row.amount,
    date: row.date,
    categoryId: row.category_id,
    accountId: row.account_id,
    toAccountId: row.to_account_id ?? undefined,
    description: row.description ?? undefined,
    tags: row.tags ? JSON.parse(row.tags) : undefined,
    isFixed: Boolean(row.is_fixed),
    isShared: Boolean(row.is_shared),
    recurringExpenseId: row.recurring_expense_id ?? undefined,
    goalId: row.goal_id ?? undefined,
    personId: row.person_id ?? undefined,
    receiptUri: row.receipt_uri ?? undefined,
    createdAt: row.created_at,
  };
}

export const transactionService = {
  getAll(limit = 100): Transaction[] {
    const db = getDb();
    const rows = db.getAllSync<any>(
      'SELECT * FROM transactions ORDER BY date DESC, created_at DESC LIMIT ?',
      [limit]
    );
    return rows.map(rowToTransaction);
  },

  getByMonth(year: number, month: number): Transaction[] {
    const db = getDb();
    const start = `${year}-${String(month).padStart(2, '0')}-01`;
    const end = `${year}-${String(month).padStart(2, '0')}-31`;
    const rows = db.getAllSync<any>(
      'SELECT * FROM transactions WHERE date >= ? AND date <= ? ORDER BY date DESC',
      [start, end]
    );
    return rows.map(rowToTransaction);
  },

  getByAccount(accountId: string, limit = 50): Transaction[] {
    const db = getDb();
    const rows = db.getAllSync<any>(
      'SELECT * FROM transactions WHERE account_id = ? ORDER BY date DESC LIMIT ?',
      [accountId, limit]
    );
    return rows.map(rowToTransaction);
  },

  getRecent(limit = 10): Transaction[] {
    const db = getDb();
    const rows = db.getAllSync<any>(
      'SELECT * FROM transactions ORDER BY date DESC, created_at DESC LIMIT ?',
      [limit]
    );
    return rows.map(rowToTransaction);
  },

  getMonthlyTotals(year: number, month: number): { income: number; expense: number; saving: number; investment: number } {
    const db = getDb();
    const start = `${year}-${String(month).padStart(2, '0')}-01`;
    const end = `${year}-${String(month).padStart(2, '0')}-31`;
    const rows = db.getAllSync<{ type: string; total: number }>(
      "SELECT type, COALESCE(SUM(amount), 0) as total FROM transactions WHERE date >= ? AND date <= ? GROUP BY type",
      [start, end]
    );
    const totals = { income: 0, expense: 0, saving: 0, investment: 0 };
    for (const r of rows) {
      if (r.type === 'income') totals.income = r.total;
      else if (r.type === 'expense') totals.expense = r.total;
      else if (r.type === 'saving') totals.saving = r.total;
      else if (r.type === 'investment') totals.investment = r.total;
    }
    return totals;
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

  create(data: Omit<Transaction, 'id' | 'createdAt'>): Transaction {
    const db = getDb();
    const id = generateId();
    const createdAt = new Date().toISOString();
    db.runSync(
      'INSERT INTO transactions (id, type, amount, date, category_id, account_id, to_account_id, description, tags, is_fixed, is_shared, recurring_expense_id, goal_id, person_id, receipt_uri, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        id, data.type, data.amount, data.date, data.categoryId, data.accountId,
        data.toAccountId ?? null, data.description ?? null,
        data.tags ? JSON.stringify(data.tags) : null,
        data.isFixed ? 1 : 0, data.isShared ? 1 : 0,
        data.recurringExpenseId ?? null, data.goalId ?? null,
        data.personId ?? null, data.receiptUri ?? null, createdAt,
      ]
    );

    // Update account balance
    const account = accountService.getById(data.accountId);
    if (account) {
      let newBalance = account.balance;
      if (data.type === 'income') newBalance += data.amount;
      else if (data.type === 'expense' || data.type === 'saving' || data.type === 'investment') newBalance -= data.amount;
      else if (data.type === 'loan_given') newBalance -= data.amount;
      else if (data.type === 'loan_received') newBalance += data.amount;
      else if (data.type === 'transfer') {
        newBalance -= data.amount;
        if (data.toAccountId) {
          const toAccount = accountService.getById(data.toAccountId);
          if (toAccount) accountService.updateBalance(data.toAccountId, toAccount.balance + data.amount);
        }
      }
      accountService.updateBalance(data.accountId, newBalance);
    }

    return { ...data, id, createdAt };
  },

  update(id: string, data: Partial<Pick<Transaction, 'description' | 'categoryId' | 'date' | 'amount'>>): void {
    const db = getDb();
    const fields: string[] = [];
    const values: any[] = [];
    if (data.description !== undefined) { fields.push('description = ?'); values.push(data.description); }
    if (data.categoryId !== undefined) { fields.push('category_id = ?'); values.push(data.categoryId); }
    if (data.date !== undefined) { fields.push('date = ?'); values.push(data.date); }
    if (data.amount !== undefined) { fields.push('amount = ?'); values.push(data.amount); }
    if (fields.length === 0) return;
    values.push(id);
    db.runSync(`UPDATE transactions SET ${fields.join(', ')} WHERE id = ?`, values);
  },

  delete(id: string): void {
    const db = getDb();
    // Reverse balance effect
    const row = db.getFirstSync<any>('SELECT * FROM transactions WHERE id = ?', [id]);
    if (row) {
      const account = accountService.getById(row.account_id);
      if (account) {
        let newBalance = account.balance;
        if (row.type === 'income') newBalance -= row.amount;
        else if (['expense', 'saving', 'investment', 'loan_given'].includes(row.type)) newBalance += row.amount;
        else if (row.type === 'loan_received') newBalance -= row.amount;
        accountService.updateBalance(row.account_id, newBalance);
      }
    }
    db.runSync('DELETE FROM transactions WHERE id = ?', [id]);
  },
};
