import { Platform } from 'react-native';
import * as SQLite from 'expo-sqlite';

const CREATE_TABLES = `
PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS accounts (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  currency TEXT NOT NULL DEFAULT 'ARS',
  balance REAL NOT NULL DEFAULT 0,
  entity TEXT,
  color TEXT NOT NULL,
  icon TEXT,
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS categories (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  icon TEXT NOT NULL,
  color TEXT NOT NULL,
  parent_id TEXT,
  type TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS transactions (
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL,
  amount REAL NOT NULL,
  date TEXT NOT NULL,
  category_id TEXT NOT NULL,
  account_id TEXT NOT NULL,
  to_account_id TEXT,
  description TEXT,
  tags TEXT,
  is_fixed INTEGER NOT NULL DEFAULT 0,
  is_shared INTEGER NOT NULL DEFAULT 0,
  recurring_expense_id TEXT,
  goal_id TEXT,
  person_id TEXT,
  receipt_uri TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS recurring_expenses (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  amount REAL NOT NULL,
  frequency TEXT NOT NULL,
  due_day INTEGER NOT NULL,
  account_id TEXT NOT NULL,
  category_id TEXT NOT NULL,
  is_active INTEGER NOT NULL DEFAULT 1,
  auto_create INTEGER NOT NULL DEFAULT 0,
  reminder INTEGER NOT NULL DEFAULT 1,
  last_paid_at TEXT,
  next_due_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS salary_rules (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  pay_day INTEGER NOT NULL,
  buckets_json TEXT NOT NULL,
  is_active INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS emergency_funds (
  id TEXT PRIMARY KEY,
  target_months INTEGER NOT NULL DEFAULT 6,
  current_amount REAL NOT NULL DEFAULT 0,
  account_id TEXT NOT NULL,
  essential_category_ids TEXT NOT NULL,
  monthly_essential_expenses REAL NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS goals (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  target_amount REAL NOT NULL,
  current_amount REAL NOT NULL DEFAULT 0,
  target_date TEXT,
  priority INTEGER NOT NULL DEFAULT 1,
  color TEXT NOT NULL,
  icon TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS persons (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  avatar TEXT,
  phone TEXT,
  color TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS shared_expenses (
  id TEXT PRIMARY KEY,
  description TEXT NOT NULL,
  total_amount REAL NOT NULL,
  date TEXT NOT NULL,
  paid_by_person_id TEXT,
  paid_by_user INTEGER NOT NULL DEFAULT 1,
  transaction_id TEXT
);

CREATE TABLE IF NOT EXISTS shared_expense_participants (
  id TEXT PRIMARY KEY,
  shared_expense_id TEXT NOT NULL,
  person_id TEXT NOT NULL,
  amount REAL NOT NULL,
  is_paid INTEGER NOT NULL DEFAULT 0,
  paid_at TEXT
);

CREATE TABLE IF NOT EXISTS debt_records (
  id TEXT PRIMARY KEY,
  person_id TEXT NOT NULL,
  amount REAL NOT NULL,
  direction TEXT NOT NULL,
  description TEXT,
  due_date TEXT,
  is_paid INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS credit_cards (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  bank TEXT NOT NULL,
  brand TEXT NOT NULL,
  last_four TEXT,
  closing_day INTEGER NOT NULL,
  due_day INTEGER NOT NULL,
  color TEXT NOT NULL,
  account_id TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS wishlist_items (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  price REAL NOT NULL,
  link TEXT,
  image_uri TEXT,
  is_need INTEGER NOT NULL DEFAULT 0,
  reminder_days INTEGER NOT NULL DEFAULT 7,
  reminder_date TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  goal_id TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS month_closures (
  id TEXT PRIMARY KEY,
  year INTEGER NOT NULL,
  month INTEGER NOT NULL,
  total_income REAL NOT NULL,
  total_expense REAL NOT NULL,
  total_saving REAL NOT NULL,
  total_investment REAL NOT NULL,
  balance REAL NOT NULL,
  notes TEXT,
  closed_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS achievements (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  icon TEXT NOT NULL,
  unlocked_at TEXT,
  is_unlocked INTEGER NOT NULL DEFAULT 0
);
`;

export async function runMigrations() {
  if (Platform.OS === 'web') return; // SQLite no disponible en web
  const db = SQLite.openDatabaseSync('finanzas.db');
  db.execSync(CREATE_TABLES);
}
