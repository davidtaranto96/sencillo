import { create } from 'zustand';
import { Category } from '@/src/lib/types';
import { categoryService } from '@/src/services/categoryService';

interface CategoryState {
  categories: Category[];
  isLoading: boolean;
  load: () => void;
  getByType: (type: 'income' | 'expense') => Category[];
  getById: (id: string) => Category | undefined;
  create: (data: Omit<Category, 'id'>) => Category;
}

export const useCategoryStore = create<CategoryState>((set, get) => ({
  categories: [],
  isLoading: false,

  load() {
    set({ isLoading: true });
    try {
      const categories = categoryService.getAll();
      set({ categories, isLoading: false });
    } catch {
      set({ isLoading: false });
    }
  },

  getByType(type) {
    return get().categories.filter((c) => c.type === type || c.type === 'both');
  },

  getById(id) {
    return get().categories.find((c) => c.id === id);
  },

  create(data) {
    const category = categoryService.create(data);
    set((state) => ({ categories: [...state.categories, category] }));
    return category;
  },
}));
