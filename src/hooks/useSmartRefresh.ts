import { useState, useCallback } from 'react';
import { dataIntegrityService, IntegrityReport } from '@/src/services/dataIntegrityService';

/**
 * Hook reutilizable para pull-to-refresh inteligente.
 *
 * Al hacer swipe-down:
 * 1. Ejecuta la limpieza de datos huérfanos e inconsistencias
 * 2. Llama las funciones de recarga que le pases
 *
 * Uso:
 *   const { refreshing, onRefresh } = useSmartRefresh(() => {
 *     loadAccounts();
 *     loadTransactions();
 *   });
 *
 *   <ScrollView refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}>
 */
export function useSmartRefresh(reloadData: () => void | Promise<void>) {
  const [refreshing, setRefreshing] = useState(false);
  const [lastReport, setLastReport] = useState<IntegrityReport | null>(null);

  const onRefresh = useCallback(async () => {
    setRefreshing(true);
    try {
      // 1. Limpiar inconsistencias
      const report = dataIntegrityService.runFullCheck();
      setLastReport(report);

      // 2. Recargar datos frescos
      await reloadData();
    } catch {
      // Silenciar errores para no romper la UX
    } finally {
      setRefreshing(false);
    }
  }, [reloadData]);

  return { refreshing, onRefresh, lastReport };
}
