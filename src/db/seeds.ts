import { Platform } from 'react-native';
import * as SQLite from 'expo-sqlite';
import { generateId } from '@/src/lib/utils';

const DEFAULT_CATEGORIES = [
  { id: 'cat-alimentacion', name: 'Alimentación', icon: 'food', color: '#F87171', type: 'expense' },
  { id: 'cat-transporte', name: 'Transporte', icon: 'car', color: '#FBBF24', type: 'expense' },
  { id: 'cat-entretenimiento', name: 'Entretenimiento', icon: 'movie-open', color: '#A78BFA', type: 'expense' },
  { id: 'cat-salud', name: 'Salud', icon: 'medical-bag', color: '#34D399', type: 'expense' },
  { id: 'cat-educacion', name: 'Educación', icon: 'book-open-variant', color: '#60A5FA', type: 'expense' },
  { id: 'cat-hogar', name: 'Hogar', icon: 'home', color: '#FB923C', type: 'expense' },
  { id: 'cat-ropa', name: 'Ropa', icon: 'tshirt-crew', color: '#F472B6', type: 'expense' },
  { id: 'cat-servicios', name: 'Servicios', icon: 'lightning-bolt', color: '#2DD4BF', type: 'expense' },
  { id: 'cat-tecnologia', name: 'Tecnología', icon: 'laptop', color: '#818CF8', type: 'expense' },
  { id: 'cat-cafe', name: 'Café y bares', icon: 'coffee', color: '#D97706', type: 'expense' },
  { id: 'cat-supermercado', name: 'Supermercado', icon: 'cart', color: '#EF4444', type: 'expense' },
  { id: 'cat-otros-gasto', name: 'Otros gastos', icon: 'dots-horizontal', color: '#6B7280', type: 'expense' },
  { id: 'cat-sueldo', name: 'Sueldo', icon: 'cash-plus', color: '#34D399', type: 'income' },
  { id: 'cat-freelance', name: 'Freelance', icon: 'briefcase', color: '#60A5FA', type: 'income' },
  { id: 'cat-inversion-ingreso', name: 'Rendimiento inversión', icon: 'trending-up', color: '#A78BFA', type: 'income' },
  { id: 'cat-otros-ingreso', name: 'Otros ingresos', icon: 'plus-circle', color: '#9898AA', type: 'income' },
];

const DEFAULT_ACCOUNT = {
  id: 'acc-efectivo',
  name: 'Efectivo',
  type: 'cash',
  currency: 'ARS',
  balance: 0,
  color: '#34D399',
  icon: 'cash',
  isActive: 1,
  createdAt: new Date().toISOString(),
};

const DEFAULT_SALARY_RULE = {
  id: 'rule-default',
  name: 'Distribución estándar',
  payDay: 25,
  bucketsJson: JSON.stringify([
    { id: 'b1', name: 'Fondo de emergencia', percentage: 15, type: 'emergency_fund', color: '#FBBF24' },
    { id: 'b2', name: 'Inversiones', percentage: 25, type: 'investment', color: '#A78BFA' },
    { id: 'b3', name: 'Gastos del mes', percentage: 50, type: 'living', color: '#60A5FA' },
    { id: 'b4', name: 'Disfrute', percentage: 10, type: 'fun', color: '#F472B6' },
  ]),
  isActive: 1,
};

export async function seedDatabase() {
  if (Platform.OS === 'web') return; // SQLite no disponible en web
  const db = SQLite.openDatabaseSync('finanzas.db');

  // Check if already seeded
  const existingCategories = db.getAllSync<{ id: string }>('SELECT id FROM categories LIMIT 1', []);
  if (existingCategories.length > 0) return;

  // Insert categories
  for (const cat of DEFAULT_CATEGORIES) {
    db.runSync(
      'INSERT OR IGNORE INTO categories (id, name, icon, color, type) VALUES (?, ?, ?, ?, ?)',
      [cat.id, cat.name, cat.icon, cat.color, cat.type]
    );
  }

  // Insert default account
  db.runSync(
    'INSERT OR IGNORE INTO accounts (id, name, type, currency, balance, color, icon, is_active, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
    [
      DEFAULT_ACCOUNT.id,
      DEFAULT_ACCOUNT.name,
      DEFAULT_ACCOUNT.type,
      DEFAULT_ACCOUNT.currency,
      DEFAULT_ACCOUNT.balance,
      DEFAULT_ACCOUNT.color,
      DEFAULT_ACCOUNT.icon,
      DEFAULT_ACCOUNT.isActive,
      DEFAULT_ACCOUNT.createdAt,
    ]
  );

  // Insert default salary rule
  db.runSync(
    'INSERT OR IGNORE INTO salary_rules (id, name, pay_day, buckets_json, is_active) VALUES (?, ?, ?, ?, ?)',
    [
      DEFAULT_SALARY_RULE.id,
      DEFAULT_SALARY_RULE.name,
      DEFAULT_SALARY_RULE.payDay,
      DEFAULT_SALARY_RULE.bucketsJson,
      DEFAULT_SALARY_RULE.isActive,
    ]
  );
}
