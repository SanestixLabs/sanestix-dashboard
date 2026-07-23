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
