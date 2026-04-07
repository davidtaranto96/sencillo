import { Transaction, TransactionType } from '@/src/lib/types';
import { generateId } from '@/src/lib/utils';
import { getDb } from '@/src/db/client';
import { accountService } from './accountService';
import { goalService } from './goalService';

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

  getMonthlyTotals(year: number, month: number): { income: number; expense: number; saving: number; investment: number; sharedExpenseTotal: number } {
    const db = getDb();
    const start = `${year}-${String(month).padStart(2, '0')}-01`;
    const end = `${year}-${String(month).padStart(2, '0')}-31`;

    // Non-shared transactions
    const rows = db.getAllSync<{ type: string; total: number }>(
      "SELECT type, COALESCE(SUM(amount), 0) as total FROM transactions WHERE date >= ? AND date <= ? AND is_shared = 0 GROUP BY type",
      [start, end]
    );
    const totals = { income: 0, expense: 0, saving: 0, investment: 0, sharedExpenseTotal: 0 };
    for (const r of rows) {
      if (r.type === 'income') totals.income = r.total;
      else if (r.type === 'expense') totals.expense = r.total;
      else if (r.type === 'saving') totals.saving = r.total;
      else if (r.type === 'investment') totals.investment = r.total;
    }

    // Shared expenses: calculate user's real portion (total - what others owe)
    const sharedRows = db.getAllSync<{ amount: number; others_owe: number }>(
      `SELECT t.amount, COALESCE(
        (SELECT SUM(p.amount) FROM shared_expense_participants p
         JOIN shared_expenses se ON p.shared_expense_id = se.id
         WHERE se.transaction_id = t.id), 0
      ) as others_owe
      FROM transactions t
      WHERE t.date >= ? AND t.date <= ? AND t.is_shared = 1 AND t.type = 'expense'`,
      [start, end]
    );
    for (const sr of sharedRows) {
      const myPortion = sr.amount - sr.others_owe;
      totals.expense += myPortion > 0 ? myPortion : sr.amount;
      totals.sharedExpenseTotal += sr.amount;
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

    db.execSync('BEGIN');
    try {
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

      db.execSync('COMMIT');
    } catch (e) {
      db.execSync('ROLLBACK');
      throw e;
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

    // If amount changed, recalculate account balance
    if (data.amount !== undefined) {
      const row = db.getFirstSync<any>('SELECT * FROM transactions WHERE id = ?', [id]);
      if (row && row.amount !== data.amount) {
        const diff = data.amount - row.amount;
        const account = accountService.getById(row.account_id);
        if (account) {
          let balanceDelta = 0;
          if (row.type === 'income') balanceDelta = diff;
          else if (['expense', 'saving', 'investment', 'loan_given'].includes(row.type)) balanceDelta = -diff;
          else if (row.type === 'loan_received') balanceDelta = diff;
          else if (row.type === 'transfer') balanceDelta = -diff;
          accountService.updateBalance(row.account_id, account.balance + balanceDelta);
        }
        // For transfers, also adjust destination account
        if (row.type === 'transfer' && row.to_account_id) {
          const toAccount = accountService.getById(row.to_account_id);
          if (toAccount) {
            accountService.updateBalance(row.to_account_id, toAccount.balance + diff);
          }
        }
      }
    }

    values.push(id);
    db.runSync(`UPDATE transactions SET ${fields.join(', ')} WHERE id = ?`, values);
  },

  delete(id: string): void {
    const db = getDb();
    const row = db.getFirstSync<any>('SELECT * FROM transactions WHERE id = ?', [id]);
    if (!row) return;

    // Wrap everything in a SQL transaction for atomicity
    db.execSync('BEGIN');
    try {
      // 1. Reverse account balance effect
      const account = accountService.getById(row.account_id);
      if (account) {
        let newBalance = account.balance;
        if (row.type === 'income') newBalance -= row.amount;
        else if (['expense', 'saving', 'investment', 'loan_given'].includes(row.type)) newBalance += row.amount;
        else if (row.type === 'loan_received') newBalance -= row.amount;
        else if (row.type === 'transfer') newBalance += row.amount;
        accountService.updateBalance(row.account_id, newBalance);
      }

      // 2. For transfers: reverse destination account
      if (row.type === 'transfer' && row.to_account_id) {
        const toAccount = accountService.getById(row.to_account_id);
        if (toAccount) {
          accountService.updateBalance(row.to_account_id, toAccount.balance - row.amount);
        }
      }

      // 3. For shared expenses: clean up related records
      if (row.is_shared) {
        // Remove debt records linked to this transaction's person
        if (row.person_id) {
          db.runSync(
            "DELETE FROM debt_records WHERE person_id = ? AND description LIKE '%' || ? || '%' AND is_paid = 0",
            [row.person_id, row.description || row.id]
          );
        }
        // Remove shared_expense_participants and shared_expenses linked via transaction_id
        const sharedExp = db.getFirstSync<any>(
          'SELECT id FROM shared_expenses WHERE transaction_id = ?',
          [id]
        );
        if (sharedExp) {
          db.runSync('DELETE FROM shared_expense_participants WHERE shared_expense_id = ?', [sharedExp.id]);
          db.runSync('DELETE FROM shared_expenses WHERE id = ?', [sharedExp.id]);
        }
      }

      // 4. For goal-linked transactions: reverse contribution
      if (row.goal_id) {
        const goal = goalService.getById(row.goal_id);
        if (goal) {
          const newAmount = Math.max(0, goal.currentAmount - row.amount);
          const newStatus = newAmount >= goal.targetAmount ? 'completed' : 'active';
          goalService.update(row.goal_id, { currentAmount: newAmount, status: newStatus });
        }
      }

      // 5. Delete the transaction
      db.runSync('DELETE FROM transactions WHERE id = ?', [id]);

      db.execSync('COMMIT');
    } catch (e) {
      db.execSync('ROLLBACK');
      throw e;
    }
  },
};
