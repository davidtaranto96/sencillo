import {
  collection, addDoc, updateDoc, deleteDoc, doc, query, where,
  onSnapshot, serverTimestamp, Unsubscribe,
} from 'firebase/firestore';
import { db } from '@/src/lib/firebase';

export type SharedExpenseSplit = {
  amount: number;
  accepted: boolean;
  localTxId: string | null;
};

export type SharedExpenseDoc = {
  id: string;
  createdByUid: string;
  createdByName: string;
  title: string;
  totalAmount: number;
  date: string;
  category?: string;
  splits: Record<string, SharedExpenseSplit>;
  status: 'active' | 'settled';
  createdAt: any;
};

/**
 * Crea un gasto compartido en Firestore
 */
export async function createSharedExpense(data: {
  createdByUid: string;
  createdByName: string;
  title: string;
  totalAmount: number;
  date: string;
  category?: string;
  splits: Record<string, SharedExpenseSplit>;
}): Promise<string> {
  const docRef = await addDoc(collection(db, 'sharedExpenses'), {
    ...data,
    status: 'active',
    createdAt: serverTimestamp(),
  });
  return docRef.id;
}

/**
 * Acepta un gasto compartido (el otro usuario confirma su parte)
 */
export async function acceptSharedExpense(
  expenseId: string,
  uid: string,
  localTxId: string,
): Promise<void> {
  await updateDoc(doc(db, 'sharedExpenses', expenseId), {
    [`splits.${uid}.accepted`]: true,
    [`splits.${uid}.localTxId`]: localTxId,
  });
}

/**
 * Elimina un gasto compartido de Firestore
 */
export async function deleteSharedExpense(expenseId: string): Promise<void> {
  await deleteDoc(doc(db, 'sharedExpenses', expenseId));
}

/**
 * Marca un gasto compartido como liquidado
 */
export async function settleSharedExpense(expenseId: string): Promise<void> {
  await updateDoc(doc(db, 'sharedExpenses', expenseId), {
    status: 'settled',
  });
}

/**
 * Escucha gastos compartidos pendientes para mí (donde no acepté todavía)
 */
export function listenToIncomingExpenses(
  myUid: string,
  callback: (expenses: SharedExpenseDoc[]) => void,
): Unsubscribe {
  // Firestore no permite filtrar por splits.${uid}.accepted directamente,
  // así que escuchamos todos los activos y filtramos en cliente
  const q = query(
    collection(db, 'sharedExpenses'),
    where('status', '==', 'active'),
  );

  return onSnapshot(q, (snap) => {
    const expenses = snap.docs
      .map((d) => ({ id: d.id, ...d.data() } as SharedExpenseDoc))
      .filter((e) => {
        const mySplit = e.splits[myUid];
        return mySplit && !mySplit.accepted;
      });
    callback(expenses);
  });
}

/**
 * Escucha gastos compartidos que yo creé
 */
export function listenToMySharedExpenses(
  myUid: string,
  callback: (expenses: SharedExpenseDoc[]) => void,
): Unsubscribe {
  const q = query(
    collection(db, 'sharedExpenses'),
    where('createdByUid', '==', myUid),
  );

  return onSnapshot(q, (snap) => {
    const expenses = snap.docs.map((d) => ({ id: d.id, ...d.data() } as SharedExpenseDoc));
    callback(expenses);
  });
}
