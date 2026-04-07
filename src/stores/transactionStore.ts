import { create } from 'zustand';
import { Transaction } from '@/src/lib/types';
import { transactionService } from '@/src/services/transactionService';

type FilterType = 'all' | 'income' | 'expense' | 'transfer';

interface TransactionState {
  transactions: Transaction[];
  filter: FilterType;
  searchQuery: string;
  isLoading: boolean;
  load: () => void;
  loadByMonth: (year: number, month: number) => void;
  setFilter: (filter: FilterType) => void;
  setSearchQuery: (query: string) => void;
  create: (data: Omit<Transaction, 'id' | 'createdAt'>) => Transaction;
  update: (id: string, data: Partial<Transaction>) => void;
  delete: (id: string) => void;
  getFiltered: () => Transaction[];
  getMonthlyTotals: (year: number, month: number) => { income: number; expense: number; saving: number; investment: number; sharedExpenseTotal: number };
}

export const useTransactionStore = create<TransactionState>((set, get) => ({
  transactions: [],
  filter: 'all',
  searchQuery: '',
  isLoading: false,

  load() {
    set({ isLoading: true });
    try {
      const transactions = transactionService.getAll();
      set({ transactions, isLoading: false });
    } catch {
      set({ isLoading: false });
    }
  },

  loadByMonth(year, month) {
    set({ isLoading: true });
    try {
      const transactions = transactionService.getByMonth(year, month);
      set({ transactions, isLoading: false });
    } catch {
      set({ isLoading: false });
    }
  },

  setFilter(filter) {
    set({ filter });
  },

  setSearchQuery(searchQuery) {
    set({ searchQuery });
  },

  create(data) {
    const transaction = transactionService.create(data);
    set((state) => ({ transactions: [transaction, ...state.transactions] }));
    return transaction;
  },

  update(id, data) {
    transactionService.update(id, data);
    set((state) => ({
      transactions: state.transactions.map((t) => (t.id === id ? { ...t, ...data } : t)),
    }));
  },

  delete(id) {
    transactionService.delete(id);
    set((state) => ({ transactions: state.transactions.filter((t) => t.id !== id) }));
  },

  getFiltered() {
    const { transactions, filter, searchQuery } = get();
    let filtered = transactions;
    if (filter !== 'all') {
      if (filter === 'transfer') {
        filtered = filtered.filter((t) => t.type === 'transfer');
      } else {
        filtered = filtered.filter((t) => t.type === filter);
      }
    }
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      filtered = filtered.filter(
        (t) => t.description?.toLowerCase().includes(q)
      );
    }
    return filtered;
  },

  getMonthlyTotals(year, month) {
    return transactionService.getMonthlyTotals(year, month);
  },
}));
