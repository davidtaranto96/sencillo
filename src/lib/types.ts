// ─── Enums ───────────────────────────────────────────────────────────────────

export type AccountType =
  | 'bank'
  | 'digital_wallet'
  | 'cash'
  | 'credit_card'
  | 'investment'
  | 'savings';

export type TransactionType =
  | 'income'
  | 'expense'
  | 'transfer'
  | 'saving'
  | 'investment'
  | 'loan_given'
  | 'loan_received';

export type FrequencyType = 'weekly' | 'monthly' | 'annual';

export type GoalStatus = 'active' | 'paused' | 'completed';

export type WishlistItemStatus = 'pending' | 'purchased' | 'discarded';

export type CardBrand = 'visa' | 'mastercard' | 'amex' | 'other';

// ─── Entidades ───────────────────────────────────────────────────────────────

export interface Account {
  id: string;
  name: string;
  type: AccountType;
  currency: string;
  balance: number;
  entity?: string;
  color: string;
  icon?: string;
  isActive: boolean;
  createdAt: string;
}

export interface Category {
  id: string;
  name: string;
  icon: string;
  color: string;
  parentId?: string;
  type: 'income' | 'expense' | 'both';
}

export interface Transaction {
  id: string;
  type: TransactionType;
  amount: number;
  date: string;
  categoryId: string;
  accountId: string;
  toAccountId?: string;
  description?: string;
  tags?: string[];
  isFixed: boolean;
  isShared: boolean;
  recurringExpenseId?: string;
  goalId?: string;
  personId?: string;
  receiptUri?: string;
  createdAt: string;
}

export interface RecurringExpense {
  id: string;
  name: string;
  amount: number;
  frequency: FrequencyType;
  dueDay: number;
  accountId: string;
  categoryId: string;
  isActive: boolean;
  autoCreate: boolean;
  reminder: boolean;
  lastPaidAt?: string;
  nextDueAt: string;
}

export interface SalaryRule {
  id: string;
  name: string;
  payDay: number;
  buckets: SalaryBucket[];
  isActive: boolean;
}

export interface SalaryBucket {
  id: string;
  name: string;
  percentage: number;
  type: 'emergency_fund' | 'investment' | 'living' | 'fun' | 'goal' | 'free';
  goalId?: string;
  color: string;
}

export interface EmergencyFund {
  id: string;
  targetMonths: number;
  currentAmount: number;
  accountId: string;
  essentialCategoryIds: string[];
  monthlyEssentialExpenses: number;
}

export interface Goal {
  id: string;
  name: string;
  description?: string;
  targetAmount: number;
  currentAmount: number;
  targetDate?: string;
  priority: number;
  color: string;
  icon?: string;
  status: GoalStatus;
  createdAt: string;
}

export interface Person {
  id: string;
  name: string;
  avatar?: string;
  phone?: string;
  color: string;
}

export interface SharedExpense {
  id: string;
  description: string;
  totalAmount: number;
  date: string;
  paidByPersonId: string;
  paidByUserId?: string;
  transactionId?: string;
  participants: SharedExpenseParticipant[];
}

export interface SharedExpenseParticipant {
  id: string;
  sharedExpenseId: string;
  personId: string;
  amount: number;
  isPaid: boolean;
  paidAt?: string;
}

export interface DebtRecord {
  id: string;
  personId: string;
  amount: number;
  direction: 'owe_me' | 'i_owe';
  description?: string;
  dueDate?: string;
  isPaid: boolean;
  createdAt: string;
}

export interface CreditCard {
  id: string;
  name: string;
  bank: string;
  brand: CardBrand;
  lastFour?: string;
  closingDay: number;
  dueDay: number;
  color: string;
  accountId: string;
}

export interface WishlistItem {
  id: string;
  name: string;
  price: number;
  link?: string;
  imageUri?: string;
  isNeed: boolean;
  reminderDays: number;
  reminderDate?: string;
  status: WishlistItemStatus;
  goalId?: string;
  createdAt: string;
}

export interface MonthClosure {
  id: string;
  year: number;
  month: number;
  totalIncome: number;
  totalExpense: number;
  totalSaving: number;
  totalInvestment: number;
  balance: number;
  notes?: string;
  closedAt: string;
}

export interface Achievement {
  id: string;
  name: string;
  description: string;
  icon: string;
  unlockedAt?: string;
  isUnlocked: boolean;
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

export interface Alert {
  id: string;
  type:
    | 'recurring_due'
    | 'card_closing'
    | 'card_due'
    | 'budget_limit'
    | 'debt_pending'
    | 'wishlist_reminder'
    | 'salary_pending'
    | 'goal_contribution';
  title: string;
  body: string;
  date: string;
  isRead: boolean;
  relatedId?: string;
}
