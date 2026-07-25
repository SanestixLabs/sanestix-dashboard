import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatCurrency(value: number, opts?: { compact?: boolean }) {
  return new Intl.NumberFormat("en-PK", {
    style: "currency",
    currency: "PKR",
    maximumFractionDigits: opts?.compact ? 1 : 0,
    notation: opts?.compact ? "compact" : "standard",
  }).format(value);
}

export function formatNumber(value: number, opts?: { compact?: boolean }) {
  return new Intl.NumberFormat("en-US", {
    maximumFractionDigits: opts?.compact ? 1 : 0,
    notation: opts?.compact ? "compact" : "standard",
  }).format(value);
}

/**
 * Turns an ISO date string into a short relative label ("Today", "In 3 days",
 * "3 days overdue") plus how many whole days away it is (negative = overdue).
 * Comparison is done on calendar dates (not exact hours) so "today" is
 * always correct regardless of what time the row's due_date carries.
 */
export function formatRelativeDate(isoDate: string): { label: string; daysUntil: number } {
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const due = new Date(isoDate);
  due.setHours(0, 0, 0, 0);

  const daysUntil = Math.round((due.getTime() - today.getTime()) / (1000 * 60 * 60 * 24));

  if (daysUntil === 0) return { label: "Today", daysUntil };
  if (daysUntil === 1) return { label: "Tomorrow", daysUntil };
  if (daysUntil === -1) return { label: "1 day overdue", daysUntil };
  if (daysUntil > 1) return { label: `In ${daysUntil} days`, daysUntil };
  return { label: `${Math.abs(daysUntil)} days overdue`, daysUntil };
}
