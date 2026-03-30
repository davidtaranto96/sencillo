import * as SQLite from 'expo-sqlite';
import { Category } from '@/src/lib/types';
import { generateId } from '@/src/lib/utils';

function getDb() {
  return SQLite.openDatabaseSync('finanzas.db');
}

function rowToCategory(row: any): Category {
  return {
    id: row.id,
    name: row.name,
    icon: row.icon,
    color: row.color,
    parentId: row.parent_id ?? undefined,
    type: row.type as Category['type'],
  };
}

export const categoryService = {
  getAll(): Category[] {
    const db = getDb();
    const rows = db.getAllSync<any>('SELECT * FROM categories ORDER BY name ASC', []);
    return rows.map(rowToCategory);
  },

  getByType(type: 'income' | 'expense' | 'both'): Category[] {
    const db = getDb();
    const rows = db.getAllSync<any>(
      "SELECT * FROM categories WHERE type = ? OR type = 'both' ORDER BY name ASC",
      [type]
    );
    return rows.map(rowToCategory);
  },

  getById(id: string): Category | null {
    const db = getDb();
    const row = db.getFirstSync<any>('SELECT * FROM categories WHERE id = ?', [id]);
    return row ? rowToCategory(row) : null;
  },

  create(data: Omit<Category, 'id'>): Category {
    const db = getDb();
    const id = generateId();
    db.runSync(
      'INSERT INTO categories (id, name, icon, color, parent_id, type) VALUES (?, ?, ?, ?, ?, ?)',
      [id, data.name, data.icon, data.color, data.parentId ?? null, data.type]
    );
    return { ...data, id };
  },
};
