import { format, formatDistanceToNow, isToday, isYesterday } from 'date-fns';
import { es } from 'date-fns/locale';

export function formatCurrency(amount: number, currency = 'ARS'): string {
  return new Intl.NumberFormat('es-AR', {
    style: 'currency',
    currency,
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(amount);
}

export function formatDate(date: string | Date): string {
  const d = typeof date === 'string' ? new Date(date) : date;
  if (isToday(d)) return 'Hoy';
  if (isYesterday(d)) return 'Ayer';
  return format(d, "d 'de' MMMM", { locale: es });
}

export function formatShortDate(date: string | Date): string {
  const d = typeof date === 'string' ? new Date(date) : date;
  return format(d, 'dd/MM/yy');
}

export function formatMonthYear(date: string | Date): string {
  const d = typeof date === 'string' ? new Date(date) : date;
  return format(d, "MMMM yyyy", { locale: es });
}

export function formatRelative(date: string | Date): string {
  const d = typeof date === 'string' ? new Date(date) : date;
  return formatDistanceToNow(d, { addSuffix: true, locale: es });
}

export function calcProgress(current: number, target: number): number {
  if (target <= 0) return 0;
  return Math.min(Math.round((current / target) * 100), 100);
}

export function calcMonthsCovered(fundAmount: number, monthlyExpenses: number): number {
  if (monthlyExpenses <= 0) return 0;
  return Math.round((fundAmount / monthlyExpenses) * 10) / 10;
}

export function calcHoursOfWork(price: number, monthlyIncome: number, hoursPerMonth = 160): number {
  if (monthlyIncome <= 0) return 0;
  const hourlyRate = monthlyIncome / hoursPerMonth;
  return Math.round((price / hourlyRate) * 10) / 10;
}

export function generateId(): string {
  return Math.random().toString(36).substring(2) + Date.now().toString(36);
}

export function getInitials(name: string): string {
  return name
    .split(' ')
    .slice(0, 2)
    .map((w) => w[0]?.toUpperCase() ?? '')
    .join('');
}

export function getDaysUntil(dateStr: string): number {
  const target = new Date(dateStr);
  const now = new Date();
  const diff = target.getTime() - now.getTime();
  return Math.ceil(diff / (1000 * 60 * 60 * 24));
}

export function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}
