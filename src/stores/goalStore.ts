import { create } from 'zustand';
import { Goal } from '@/src/lib/types';
import { goalService } from '@/src/services/goalService';

interface GoalState {
  goals: Goal[];
  isLoading: boolean;
  load: () => void;
  create: (data: Omit<Goal, 'id' | 'createdAt' | 'currentAmount'>) => Goal;
  update: (id: string, data: Partial<Goal>) => void;
  addContribution: (id: string, amount: number) => void;
}

export const useGoalStore = create<GoalState>((set, get) => ({
  goals: [],
  isLoading: false,

  load() {
    set({ isLoading: true });
    try {
      const goals = goalService.getAll();
      set({ goals, isLoading: false });
    } catch {
      set({ isLoading: false });
    }
  },

  create(data) {
    const goal = goalService.create(data);
    set((state) => ({ goals: [...state.goals, goal] }));
    return goal;
  },

  update(id, data) {
    goalService.update(id, data);
    set((state) => ({
      goals: state.goals.map((g) => (g.id === id ? { ...g, ...data } : g)),
    }));
  },

  addContribution(id, amount) {
    const updated = goalService.addContribution(id, amount);
    if (!updated) return;
    set((state) => ({
      goals: state.goals.map((g) => (g.id === id ? updated : g)),
    }));
  },
}));
