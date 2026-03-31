import * as SQLite from 'expo-sqlite';
import { drizzle } from 'drizzle-orm/expo-sqlite';
import * as schema from './schema';

const sqlite = SQLite.openDatabaseSync('finanzas.db');
export const db = drizzle(sqlite, { schema });

export type DB = typeof db;
