import { create } from 'zustand';
import { Account } from '@/src/lib/types';
import { accountService } from '@/src/services/accountService';

interface AccountState {
  accounts: Account[];
  totalBalance: number;
  isLoading: boolean;
  load: () => void;
  create: (data: Omit<Account, 'id' | 'createdAt'>) => Account;
  update: (id: string, data: Partial<Account>) => void;
  updateBalance: (id: string, balance: number) => void;
  delete: (id: string) => void;
}

export const useAccountStore = create<AccountState>((set, get) => ({
  accounts: [],
  totalBalance: 0,
  isLoading: false,

  load() {
    set({ isLoading: true });
    try {
      const accounts = accountService.getAll();
      const totalBalance = accountService.getTotalBalance();
      set({ accounts, totalBalance, isLoading: false });
    } catch {
      set({ isLoading: false });
    }
  },

  create(data) {
    const account = accountService.create(data);
    set((state) => ({
      accounts: [...state.accounts, account],
      totalBalance: accountService.getTotalBalance(),
    }));
    return account;
  },

  update(id, data) {
    accountService.update(id, data);
    set((state) => ({
      accounts: state.accounts.map((a) => (a.id === id ? { ...a, ...data } : a)),
      totalBalance: accountService.getTotalBalance(),
    }));
  },

  updateBalance(id, balance) {
    accountService.updateBalance(id, balance);
    set((state) => ({
      accounts: state.accounts.map((a) => (a.id === id ? { ...a, balance } : a)),
      totalBalance: accountService.getTotalBalance(),
    }));
  },

  delete(id) {
    accountService.delete(id);
    set((state) => ({
      accounts: state.accounts.filter((a) => a.id !== id),
      totalBalance: accountService.getTotalBalance(),
    }));
  },
}));
