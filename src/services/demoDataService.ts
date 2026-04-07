import { Platform } from 'react-native';
import { getDb } from '@/src/db/client';

const DEMO_PREFIX = 'demo-';

// ─── Demo Accounts ──────────────────────────────────────────────────────────

const DEMO_ACCOUNTS = [
  { id: `${DEMO_PREFIX}acc-efectivo`, name: 'Efectivo', type: 'cash', currency: 'ARS', balance: 52300, color: '#34D399', icon: 'cash' },
  { id: `${DEMO_PREFIX}acc-banco`, name: 'Banco Galicia', type: 'bank', currency: 'ARS', balance: 185000, color: '#60A5FA', icon: 'bank' },
  { id: `${DEMO_PREFIX}acc-mp`, name: 'Mercado Pago', type: 'digital_wallet', currency: 'ARS', balance: 28750, color: '#009ee3', icon: 'cellphone' },
];

// ─── Demo Goals ─────────────────────────────────────────────────────────────

const DEMO_GOALS = [
  { id: `${DEMO_PREFIX}goal-europa`, name: 'Viaje a Europa', targetAmount: 2000000, currentAmount: 450000, color: '#6C63FF', icon: 'airplane', priority: 1 },
  { id: `${DEMO_PREFIX}goal-notebook`, name: 'Notebook nueva', targetAmount: 800000, currentAmount: 320000, color: '#F472B6', icon: 'laptop', priority: 2 },
];

// ─── Demo Transactions ──────────────────────────────────────────────────────

function daysAgo(n: number): string {
  const d = new Date();
  d.setDate(d.getDate() - n);
  return d.toISOString();
}

function makeTx(id: string, type: string, amount: number, desc: string, catId: string, accId: string, daysBack: number, toAccId?: string) {
  return { id: `${DEMO_PREFIX}tx-${id}`, type, amount, description: desc, categoryId: catId, accountId: accId, toAccountId: toAccId ?? null, date: daysAgo(daysBack) };
}

const ACC_BANCO = `${DEMO_PREFIX}acc-banco`;
const ACC_MP = `${DEMO_PREFIX}acc-mp`;
const ACC_CASH = `${DEMO_PREFIX}acc-efectivo`;

const DEMO_TRANSACTIONS = [
  // Ingresos
  makeTx('sueldo', 'income', 450000, 'Sueldo marzo', 'cat-sueldo', ACC_BANCO, 28),
  makeTx('freelance1', 'income', 85000, 'Proyecto web freelance', 'cat-freelance', ACC_MP, 20),

  // Gastos
  makeTx('super1', 'expense', 35200, 'Supermercado semanal', 'cat-supermercado', ACC_CASH, 2),
  makeTx('super2', 'expense', 28500, 'Supermercado', 'cat-supermercado', ACC_CASH, 9),
  makeTx('super3', 'expense', 32100, 'Compras Coto', 'cat-supermercado', ACC_BANCO, 16),
  makeTx('cafe1', 'expense', 4500, 'Café con amigos', 'cat-cafe', ACC_MP, 1),
  makeTx('cafe2', 'expense', 3800, 'Starbucks', 'cat-cafe', ACC_CASH, 7),
  makeTx('trans1', 'expense', 12000, 'Carga SUBE', 'cat-transporte', ACC_CASH, 3),
  makeTx('trans2', 'expense', 8500, 'Uber a la oficina', 'cat-transporte', ACC_MP, 10),
  makeTx('entret1', 'expense', 15000, 'Netflix + Spotify', 'cat-entretenimiento', ACC_BANCO, 5),
  makeTx('entret2', 'expense', 22000, 'Cine + pochoclo', 'cat-entretenimiento', ACC_MP, 12),
  makeTx('serv1', 'expense', 18500, 'Factura de luz', 'cat-servicios', ACC_BANCO, 8),
  makeTx('serv2', 'expense', 9800, 'Internet Fibertel', 'cat-servicios', ACC_BANCO, 14),
  makeTx('tech1', 'expense', 45000, 'Auriculares Bluetooth', 'cat-tecnologia', ACC_MP, 6),
  makeTx('alim1', 'expense', 6200, 'Pedidos Ya almuerzo', 'cat-alimentacion', ACC_MP, 0),
  makeTx('alim2', 'expense', 8900, 'Rappi cena', 'cat-alimentacion', ACC_CASH, 4),
  makeTx('ropa1', 'expense', 35000, 'Zapatillas Nike', 'cat-ropa', ACC_BANCO, 18),

  // Transferencia
  makeTx('transf1', 'transfer', 30000, 'Paso a MP', 'cat-otros-gasto', ACC_BANCO, 11, ACC_MP),

  // Ahorro
  makeTx('saving1', 'saving', 50000, 'Aporte a fondo europa', 'cat-otros-gasto', ACC_BANCO, 15),
];

// ��── Funciones públicas ────────────────────────────────────��────────────────

export function seedDemoData(): void {
  if (Platform.OS === 'web') return;
  const db = getDb();
  const now = new Date().toISOString();

  // Accounts
  for (const acc of DEMO_ACCOUNTS) {
    db.runSync(
      'INSERT OR REPLACE INTO accounts (id, name, type, currency, balance, color, icon, is_active, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?)',
      [acc.id, acc.name, acc.type, acc.currency, acc.balance, acc.color, acc.icon, now]
    );
  }

  // Goals
  for (const g of DEMO_GOALS) {
    db.runSync(
      'INSERT OR REPLACE INTO goals (id, name, target_amount, current_amount, color, icon, priority, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [g.id, g.name, g.targetAmount, g.currentAmount, g.color, g.icon, g.priority, 'active', now]
    );
  }

  // Transactions
  for (const tx of DEMO_TRANSACTIONS) {
    db.runSync(
      'INSERT OR REPLACE INTO transactions (id, type, amount, date, category_id, account_id, to_account_id, description, is_fixed, is_shared, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, 0, ?)',
      [tx.id, tx.type, tx.amount, tx.date, tx.categoryId, tx.accountId, tx.toAccountId, tx.description, now]
    );
  }
}

export function clearDemoData(): void {
  if (Platform.OS === 'web') return;
  const db = getDb();

  // Clean up in dependency order to avoid FK issues
  db.runSync(`DELETE FROM shared_expense_participants WHERE shared_expense_id IN (SELECT id FROM shared_expenses WHERE transaction_id IN (SELECT id FROM transactions WHERE id LIKE '${DEMO_PREFIX}%'))`);
  db.runSync(`DELETE FROM shared_expenses WHERE transaction_id IN (SELECT id FROM transactions WHERE id LIKE '${DEMO_PREFIX}%')`);
  db.runSync(`DELETE FROM debt_records WHERE id LIKE '${DEMO_PREFIX}%'`);
  db.runSync(`DELETE FROM credit_cards WHERE id LIKE '${DEMO_PREFIX}%'`);
  db.runSync(`DELETE FROM recurring_expenses WHERE id LIKE '${DEMO_PREFIX}%'`);
  db.runSync(`DELETE FROM transactions WHERE id LIKE '${DEMO_PREFIX}%'`);
  db.runSync(`DELETE FROM goals WHERE id LIKE '${DEMO_PREFIX}%'`);
  db.runSync(`DELETE FROM accounts WHERE id LIKE '${DEMO_PREFIX}%'`);
}

export function isDemoDataLoaded(): boolean {
  if (Platform.OS === 'web') return false;
  const db = getDb();
  const result = db.getFirstSync<{ count: number }>(
    `SELECT COUNT(*) as count FROM accounts WHERE id LIKE '${DEMO_PREFIX}%'`
  );
  return (result?.count ?? 0) > 0;
}
