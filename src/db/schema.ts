import { sqliteTable, text, integer, real } from 'drizzle-orm/sqlite-core';

// ─── Accounts ────────────────────────────────────────────────────────────────
export const accounts = sqliteTable('accounts', {
  id: text('id').primaryKey(),
  name: text('name').notNull(),
  type: text('type').notNull(), // AccountType
  currency: text('currency').notNull().default('ARS'),
  balance: real('balance').notNull().default(0),
  entity: text('entity'),
  color: text('color').notNull(),
  icon: text('icon'),
  isActive: integer('is_active', { mode: 'boolean' }).notNull().default(true),
  createdAt: text('created_at').notNull(),
});

// ─── Categories ───────────────────────────────────────────────────────────────
export const categories = sqliteTable('categories', {
  id: text('id').primaryKey(),
  name: text('name').notNull(),
  icon: text('icon').notNull(),
  color: text('color').notNull(),
  parentId: text('parent_id'),
  type: text('type').notNull(), // 'income' | 'expense' | 'both'
});

// ─── Transactions ─────────────────────────────────────────────────────────────
export const transactions = sqliteTable('transactions', {
  id: text('id').primaryKey(),
  type: text('type').notNull(), // TransactionType
  amount: real('amount').notNull(),
  date: text('date').notNull(),
  categoryId: text('category_id').notNull().references(() => categories.id),
  accountId: text('account_id').notNull().references(() => accounts.id),
  toAccountId: text('to_account_id').references(() => accounts.id),
  description: text('description'),
  tags: text('tags'), // JSON array
  isFixed: integer('is_fixed', { mode: 'boolean' }).notNull().default(false),
  isShared: integer('is_shared', { mode: 'boolean' }).notNull().default(false),
  recurringExpenseId: text('recurring_expense_id'),
  goalId: text('goal_id'),
  personId: text('person_id'),
  receiptUri: text('receipt_uri'),
  createdAt: text('created_at').notNull(),
});

// ─── Recurring Expenses ───────────────────────────────────────────────────────
export const recurringExpenses = sqliteTable('recurring_expenses', {
  id: text('id').primaryKey(),
  name: text('name').notNull(),
  amount: real('amount').notNull(),
  frequency: text('frequency').notNull(), // FrequencyType
  dueDay: integer('due_day').notNull(),
  accountId: text('account_id').notNull().references(() => accounts.id),
  categoryId: text('category_id').notNull().references(() => categories.id),
  isActive: integer('is_active', { mode: 'boolean' }).notNull().default(true),
  autoCreate: integer('auto_create', { mode: 'boolean' }).notNull().default(false),
  reminder: integer('reminder', { mode: 'boolean' }).notNull().default(true),
  lastPaidAt: text('last_paid_at'),
  nextDueAt: text('next_due_at').notNull(),
});

// ─── Salary Rules ─────────────────────────────────────────────────────────────
export const salaryRules = sqliteTable('salary_rules', {
  id: text('id').primaryKey(),
  name: text('name').notNull(),
  payDay: integer('pay_day').notNull(),
  bucketsJson: text('buckets_json').notNull(), // JSON SalaryBucket[]
  isActive: integer('is_active', { mode: 'boolean' }).notNull().default(true),
});

// ─── Emergency Fund ───────────────────────────────────────────────────────────
export const emergencyFunds = sqliteTable('emergency_funds', {
  id: text('id').primaryKey(),
  targetMonths: integer('target_months').notNull().default(6),
  currentAmount: real('current_amount').notNull().default(0),
  accountId: text('account_id').notNull().references(() => accounts.id),
  essentialCategoryIds: text('essential_category_ids').notNull(), // JSON array
  monthlyEssentialExpenses: real('monthly_essential_expenses').notNull().default(0),
});

// ─── Goals ────────────────────────────────────────────────────────────────────
export const goals = sqliteTable('goals', {
  id: text('id').primaryKey(),
  name: text('name').notNull(),
  description: text('description'),
  targetAmount: real('target_amount').notNull(),
  currentAmount: real('current_amount').notNull().default(0),
  targetDate: text('target_date'),
  priority: integer('priority').notNull().default(1),
  color: text('color').notNull(),
  icon: text('icon'),
  status: text('status').notNull().default('active'), // GoalStatus
  createdAt: text('created_at').notNull(),
});

// ─── Persons ──────────────────────────────────────────────────────────────────
export const persons = sqliteTable('persons', {
  id: text('id').primaryKey(),
  name: text('name').notNull(),
  avatar: text('avatar'),
  phone: text('phone'),
  color: text('color').notNull(),
});

// ─── Shared Expenses ──────────────────────────────────────────────────────────
export const sharedExpenses = sqliteTable('shared_expenses', {
  id: text('id').primaryKey(),
  description: text('description').notNull(),
  totalAmount: real('total_amount').notNull(),
  date: text('date').notNull(),
  paidByPersonId: text('paid_by_person_id'),
  paidByUser: integer('paid_by_user', { mode: 'boolean' }).notNull().default(true),
  transactionId: text('transaction_id'),
});

export const sharedExpenseParticipants = sqliteTable('shared_expense_participants', {
  id: text('id').primaryKey(),
  sharedExpenseId: text('shared_expense_id').notNull().references(() => sharedExpenses.id),
  personId: text('person_id').notNull().references(() => persons.id),
  amount: real('amount').notNull(),
  isPaid: integer('is_paid', { mode: 'boolean' }).notNull().default(false),
  paidAt: text('paid_at'),
});

// ─── Debt Records ─────────────────────────────────────────────────────────────
export const debtRecords = sqliteTable('debt_records', {
  id: text('id').primaryKey(),
  personId: text('person_id').notNull().references(() => persons.id),
  amount: real('amount').notNull(),
  direction: text('direction').notNull(), // 'owe_me' | 'i_owe'
  description: text('description'),
  dueDate: text('due_date'),
  isPaid: integer('is_paid', { mode: 'boolean' }).notNull().default(false),
  createdAt: text('created_at').notNull(),
});

// ─── Credit Cards ─────────────────────────────────────────────────────────────
export const creditCards = sqliteTable('credit_cards', {
  id: text('id').primaryKey(),
  name: text('name').notNull(),
  bank: text('bank').notNull(),
  brand: text('brand').notNull(), // CardBrand
  lastFour: text('last_four'),
  closingDay: integer('closing_day').notNull(),
  dueDay: integer('due_day').notNull(),
  color: text('color').notNull(),
  accountId: text('account_id').notNull().references(() => accounts.id),
});

// ─── Wishlist ─────────────────────────────────────────────────────────────────
export const wishlistItems = sqliteTable('wishlist_items', {
  id: text('id').primaryKey(),
  name: text('name').notNull(),
  price: real('price').notNull(),
  link: text('link'),
  imageUri: text('image_uri'),
  isNeed: integer('is_need', { mode: 'boolean' }).notNull().default(false),
  reminderDays: integer('reminder_days').notNull().default(7),
  reminderDate: text('reminder_date'),
  status: text('status').notNull().default('pending'), // WishlistItemStatus
  goalId: text('goal_id'),
  createdAt: text('created_at').notNull(),
});

// ─── Month Closures ───────────────────────────────────────────────────────────
export const monthClosures = sqliteTable('month_closures', {
  id: text('id').primaryKey(),
  year: integer('year').notNull(),
  month: integer('month').notNull(),
  totalIncome: real('total_income').notNull(),
  totalExpense: real('total_expense').notNull(),
  totalSaving: real('total_saving').notNull(),
  totalInvestment: real('total_investment').notNull(),
  balance: real('balance').notNull(),
  notes: text('notes'),
  closedAt: text('closed_at').notNull(),
});

// ─── Achievements ─────────────────────────────────────────────────────────────
export const achievements = sqliteTable('achievements', {
  id: text('id').primaryKey(),
  name: text('name').notNull(),
  description: text('description').notNull(),
  icon: text('icon').notNull(),
  unlockedAt: text('unlocked_at'),
  isUnlocked: integer('is_unlocked', { mode: 'boolean' }).notNull().default(false),
});
