import type { InvoiceLineItem } from "./types";

export interface InvoiceTotals {
  subtotal: number;
  taxAmount: number;
  total: number;
}

export function lineItemAmount(item: InvoiceLineItem): number {
  const qty = Number.isFinite(item.quantity) ? item.quantity : 0;
  const rate = Number.isFinite(item.rate) ? item.rate : 0;
  return qty * rate;
}

export function computeTotals(items: InvoiceLineItem[], taxPercent: number): InvoiceTotals {
  const subtotal = items.reduce((sum, item) => sum + lineItemAmount(item), 0);
  const taxAmount = subtotal * (Number.isFinite(taxPercent) ? taxPercent / 100 : 0);
  const total = subtotal + taxAmount;
  return { subtotal, taxAmount, total };
}

export function formatMoney(value: number, currency: string): string {
  const rounded = Math.round((Number.isFinite(value) ? value : 0) * 100) / 100;
  const parts = rounded.toLocaleString("en-US", {
    minimumFractionDigits: rounded % 1 === 0 ? 0 : 2,
    maximumFractionDigits: 2,
  });
  return `${currency} ${parts}`;
}

export function formatDateLong(iso: string): string {
  if (!iso) return "";
  const [y, m, d] = iso.split("-").map(Number);
  if (!y || !m || !d) return iso;
  const date = new Date(Date.UTC(y, m - 1, d));
  return date.toLocaleDateString("en-US", {
    month: "long",
    day: "numeric",
    year: "numeric",
    timeZone: "UTC",
  });
}
