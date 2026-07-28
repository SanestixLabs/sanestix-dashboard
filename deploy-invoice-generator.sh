#!/usr/bin/env bash
# Sanestix Dashboard — Invoice Generator feature installer
# Run this from the ROOT of your sanestix-dashboard project on the VPS
# (the directory containing package.json and docker-compose.yml).
set -euo pipefail

if [ ! -f package.json ] || [ ! -d src/app ]; then
  echo "ERROR: run this from the sanestix-dashboard project root (where package.json lives)."
  exit 1
fi

echo "==> Creating directories"
mkdir -p "src/app/api/invoices/docx"
mkdir -p "src/app/api/invoices/pdf"
mkdir -p "src/app/finance/invoices/generator"
mkdir -p "src/components/invoice-generator"
mkdir -p "src/components/layout"
mkdir -p "src/lib/invoice-generator"

echo "==> Writing package.json"
cat > "package.json" << 'SANESTIX_FILE_0_EOF'
{
  "name": "sanestix-dashboard",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "eslint",
    "setup:founders": "node scripts/setup-founders.mjs"
  },
  "overrides": {
    "postcss": "8.5.22",
    "sharp": "0.35.3"
  },
  "dependencies": {
    "@react-pdf/renderer": "^4.5.1",
    "@supabase/ssr": "^0.12.3",
    "@supabase/supabase-js": "^2.110.8",
    "clsx": "^2.1.1",
    "docx": "^9.7.1",
    "lucide-react": "^1.25.0",
    "next": "16.2.11",
    "react": "19.2.4",
    "react-dom": "19.2.4",
    "recharts": "^3.10.0",
    "tailwind-merge": "^3.6.0",
    "ws": "^8.21.1"
  },
  "devDependencies": {
    "@tailwindcss/postcss": "^4",
    "@types/node": "^20",
    "@types/react": "^19",
    "@types/react-dom": "^19",
    "eslint": "^9",
    "eslint-config-next": "16.2.11",
    "tailwindcss": "^4",
    "typescript": "^5"
  }
}
SANESTIX_FILE_0_EOF

echo "==> Writing Dockerfile"
cat > "Dockerfile" << 'SANESTIX_FILE_1_EOF'
# --- deps ---------------------------------------------------------------
FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm install

# --- builder --------------------------------------------------------------
FROM node:20-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

ENV NEXT_TELEMETRY_DISABLED=1

# NEXT_PUBLIC_* vars are inlined into the client bundle at build time, so
# they must arrive as build args (from docker-compose's `args:`), not just
# runtime env. Server-only vars (e.g. SUPABASE_SERVICE_ROLE_KEY) don't need
# this — they're read from the container's runtime env in server code.
ARG NEXT_PUBLIC_SUPABASE_URL
ARG NEXT_PUBLIC_SUPABASE_ANON_KEY
ARG NEXT_PUBLIC_SITE_URL
ENV NEXT_PUBLIC_SUPABASE_URL=$NEXT_PUBLIC_SUPABASE_URL
ENV NEXT_PUBLIC_SUPABASE_ANON_KEY=$NEXT_PUBLIC_SUPABASE_ANON_KEY
ENV NEXT_PUBLIC_SITE_URL=$NEXT_PUBLIC_SITE_URL

RUN npm run build

# --- runner (final image) --------------------------------------------------
FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000
ENV HOSTNAME=0.0.0.0

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# Standalone output: a minimal server.js plus only the deps it needs.
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs
EXPOSE 3000

CMD ["node", "server.js"]
SANESTIX_FILE_1_EOF

echo "==> Writing src/components/layout/sidebar.tsx"
cat > "src/components/layout/sidebar.tsx" << 'SANESTIX_FILE_2_EOF'
"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  LayoutDashboard,
  Wallet,
  Kanban,
  Users,
  FileText,
  Settings,
  HelpCircle,
  LogOut,
  ChevronDown,
  ChevronUp,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { LogoutButton } from "@/components/auth/logout-button";

const NAV_ITEMS = [
  { label: "Dashboard", icon: LayoutDashboard, href: "/" },
  { label: "Finance", icon: Wallet, href: "/finance" },
  { label: "Projects", icon: Kanban, href: "/projects" },
  { label: "CRM", icon: Users, href: "/crm" },
  { label: "Reports", icon: FileText, href: "/reports" },
  { label: "Settings", icon: Settings, href: "/settings" },
];

// Moved here from the old FinanceTabs bar at the top of every finance page —
// now lives as a submenu under the Finance nav item instead.
const FINANCE_SUB_ITEMS = [
  { label: "Overview", href: "/finance" },
  { label: "Income", href: "/finance/income" },
  { label: "Expenses", href: "/finance/expenses" },
  { label: "Transactions", href: "/finance/transactions" },
  { label: "Invoices", href: "/finance/invoices" },
  { label: "Invoice Generator", href: "/finance/invoices/generator" },
  { label: "Investments", href: "/finance/investments" },
  { label: "Reimbursements", href: "/finance/reimbursements" },
  { label: "Founder Entry", href: "/finance/loans" },
  { label: "Profit Split", href: "/finance/profit-split" },
  { label: "Reports", href: "/finance/reports" },
  { label: "Vendors", href: "/finance/vendors" },
  { label: "Employees", href: "/finance/employees" },
  { label: "Subscriptions", href: "/finance/subscriptions" },
  { label: "Assets", href: "/finance/assets" },
  { label: "Debts", href: "/finance/debts" },
];

function getInitials(email?: string) {
  if (!email) return "SU";
  return email
    .split("@")[0]
    .split(/[._-]/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase())
    .join("");
}

export function Sidebar({ userEmail }: { userEmail?: string }) {
  const pathname = usePathname();
  const [financeExpanded, setFinanceExpanded] = useState(true);
  const [mobileFinanceOpen, setMobileFinanceOpen] = useState(false);

  const financeActive = pathname === "/finance" || pathname.startsWith("/finance/");

  // Close the mobile drawer if the user navigates away from Finance
  // entirely (e.g. via the desktop sidebar in a resized window, or a link
  // elsewhere in the app).
  useEffect(() => {
    if (!financeActive) setMobileFinanceOpen(false);
  }, [financeActive]);

  return (
    <>
      <aside className="fixed left-0 top-0 z-50 hidden h-full w-[248px] flex-col border-r border-outline-variant bg-surface py-4 lg:flex">
        <div className="mb-8 px-5">
          <span className="text-[20px] font-bold tracking-tight text-primary">
            Sanestix
          </span>
          <p className="mt-1 text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Operations OS
          </p>
        </div>

        <nav className="sidebar-scroll flex-1 space-y-1 overflow-y-auto px-3">
          {NAV_ITEMS.map(({ label, icon: Icon, href }) => {
            const active = href === "/" ? pathname === "/" : pathname.startsWith(href);
            const isFinance = label === "Finance";

            return (
              <div key={label}>
                <Link
                  href={href}
                  onClick={(e) => {
                    if (!isFinance) return;
                    if (active) {
                      // Already on a Finance page: clicking anywhere on the
                      // row just toggles the submenu open/closed.
                      e.preventDefault();
                      setFinanceExpanded((v) => !v);
                    } else {
                      // Navigating into Finance for the first time: open it.
                      setFinanceExpanded(true);
                    }
                  }}
                  className={cn(
                    "group flex w-full items-center gap-3 px-3 py-2.5 text-left text-[13px] font-medium transition-all duration-200 ease-out",
                    active
                      ? "border-l-2 border-primary bg-primary/[0.06] text-primary"
                      : "border-l-2 border-transparent text-on-surface-variant hover:translate-x-0.5 hover:border-primary/40 hover:bg-primary/[0.04] hover:text-on-surface"
                  )}
                >
                  <Icon
                    size={17}
                    strokeWidth={2}
                    className="transition-transform duration-200 ease-out group-hover:scale-110"
                  />
                  <span className="flex-1">{label}</span>
                  {isFinance && (
                    <ChevronDown
                      size={14}
                      className={cn(
                        "transition-transform duration-200 ease-out",
                        financeExpanded && "rotate-180"
                      )}
                    />
                  )}
                </Link>

                {isFinance && active && financeExpanded && (
                  <div className="ml-[26px] mt-1 space-y-0.5 border-l border-outline-variant pl-3">
                    {FINANCE_SUB_ITEMS.map((tab) => {
                      const tabActive = pathname === tab.href;
                      return (
                        <Link
                          key={tab.href}
                          href={tab.href}
                          className={cn(
                            "block px-2 py-1.5 font-mono-data text-[11px] uppercase tracking-wider transition-all duration-200 ease-out",
                            tabActive
                              ? "text-primary"
                              : "text-on-surface-variant hover:translate-x-0.5 hover:text-on-surface"
                          )}
                        >
                          {tab.label}
                        </Link>
                      );
                    })}
                  </div>
                )}
              </div>
            );
          })}
        </nav>

        <div className="space-y-1 px-3 pt-4">
          <Link
            href="/help"
            className="flex w-full items-center gap-3 px-3 py-2 text-[11px] font-mono-data uppercase tracking-wider text-on-surface-variant hover:text-on-surface"
          >
            <HelpCircle size={15} />
            Help
          </Link>
          <LogoutButton className="flex w-full items-center gap-3 px-3 py-2 text-[11px] font-mono-data uppercase tracking-wider text-on-surface-variant hover:text-error">
            <LogOut size={15} />
            Sign out
          </LogoutButton>

          <div className="mt-3 flex items-center justify-between border border-outline-variant bg-background px-3 py-2.5">
            <div className="flex min-w-0 items-center gap-2.5">
              <div className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full border border-primary/20 bg-primary/10 text-[11px] font-semibold text-primary">
                {getInitials(userEmail)}
              </div>
              <div className="flex min-w-0 flex-col leading-none">
                <span className="truncate text-[11px] font-semibold text-on-surface">
                  {userEmail ?? "Signed in"}
                </span>
                <span className="mt-1 text-[9px] uppercase tracking-wider text-on-surface-variant">
                  Team member
                </span>
              </div>
            </div>
          </div>
        </div>
      </aside>

      {/* Mobile Finance submenu drawer — backdrop + sheet, sits above the bottom tab bar */}
      {mobileFinanceOpen && (
        <>
          <button
            aria-label="Close Finance menu"
            onClick={() => setMobileFinanceOpen(false)}
            className="fixed inset-0 z-40 bg-black/40 lg:hidden"
          />
          <div className="fixed inset-x-0 bottom-[56px] z-50 max-h-[60vh] overflow-y-auto border-t border-outline-variant bg-surface pb-2 lg:hidden">
            <div className="flex items-center justify-between px-4 py-3">
              <span className="font-mono-data text-[11px] uppercase tracking-widest text-on-surface-variant/70">
                Finance
              </span>
              <button
                onClick={() => setMobileFinanceOpen(false)}
                className="text-on-surface-variant"
                aria-label="Close"
              >
                <ChevronUp size={16} />
              </button>
            </div>
            <div className="grid grid-cols-2 gap-1 px-3 pb-3">
              {FINANCE_SUB_ITEMS.map((tab) => {
                const tabActive = pathname === tab.href;
                return (
                  <Link
                    key={tab.href}
                    href={tab.href}
                    onClick={() => setMobileFinanceOpen(false)}
                    className={cn(
                      "border border-outline-variant px-3 py-2.5 text-center font-mono-data text-[11px] uppercase tracking-wider transition-colors",
                      tabActive
                        ? "border-primary/40 bg-primary/[0.06] text-primary"
                        : "text-on-surface-variant hover:text-on-surface"
                    )}
                  >
                    {tab.label}
                  </Link>
                );
              })}
            </div>
          </div>
        </>
      )}

      <nav className="fixed inset-x-0 bottom-0 z-50 grid grid-cols-5 border-t border-outline-variant bg-surface/95 px-2 py-1.5 backdrop-blur lg:hidden">
        {NAV_ITEMS.slice(0, 5).map(({ label, icon: Icon, href }) => {
          const active = href === "/" ? pathname === "/" : pathname.startsWith(href);
          const isFinance = label === "Finance";

          return (
            <Link
              key={label}
              href={href}
              onClick={(e) => {
                if (!isFinance) return;
                if (active) {
                  // Already on a Finance page: tap toggles the drawer instead
                  // of re-navigating.
                  e.preventDefault();
                  setMobileFinanceOpen((v) => !v);
                } else {
                  setMobileFinanceOpen(true);
                }
              }}
              className={cn(
                "flex min-w-0 flex-col items-center gap-1 px-1 py-2 text-[10px] font-medium transition-colors",
                active ? "text-primary" : "text-on-surface-variant"
              )}
            >
              <Icon size={18} strokeWidth={2} />
              <span className="w-full truncate text-center">{label}</span>
            </Link>
          );
        })}
      </nav>
    </>
  );
}
SANESTIX_FILE_2_EOF

echo "==> Writing src/lib/invoice-generator/types.ts"
cat > "src/lib/invoice-generator/types.ts" << 'SANESTIX_FILE_3_EOF'
export interface InvoiceLineItem {
  id: string;
  description: string;
  quantity: number;
  rate: number;
}

export interface InvoiceParty {
  name: string;
  tagline?: string;
  email?: string;
  phone?: string;
  addressLine1?: string;
  addressLine2?: string;
}

export interface InvoiceClient {
  name: string;
  typeLabel?: string; // e.g. "BUSINESS" / "INDIVIDUAL"
  company?: string;
  website?: string;
}

export interface InvoiceDocument {
  invoiceNumber: string;
  issueDate: string; // ISO yyyy-mm-dd
  dueDate: string; // ISO yyyy-mm-dd
  currency: string; // e.g. "PKR"
  sender: InvoiceParty;
  client: InvoiceClient;
  items: InvoiceLineItem[];
  taxPercent: number;
  notes: string;
  paymentTerms: string;
  thankYouLine: string;
  footerLine: string;
}

export function createEmptyLineItem(): InvoiceLineItem {
  return {
    id: crypto.randomUUID(),
    description: "",
    quantity: 1,
    rate: 0,
  };
}

export function generateInvoiceNumber(prefix = "STX"): string {
  const now = new Date();
  const yy = String(now.getFullYear()).slice(2);
  const mm = String(now.getMonth() + 1).padStart(2, "0");
  const dd = String(now.getDate()).padStart(2, "0");
  const suffix = String.fromCharCode(65 + Math.floor(Math.random() * 26));
  return `${prefix}-${yy}${mm}${dd}-${suffix}`;
}

export function defaultInvoiceDocument(): InvoiceDocument {
  const today = new Date().toISOString().slice(0, 10);
  const due = new Date(Date.now() + 5 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);

  return {
    invoiceNumber: generateInvoiceNumber(),
    issueDate: today,
    dueDate: due,
    currency: "PKR",
    sender: {
      name: "Sanestix",
      tagline: "",
      email: "contact@sanestix.com",
      phone: "+92-301-4422951",
      addressLine1: "85-H Valencia Town,",
      addressLine2: "Lahore, Pakistan",
    },
    client: {
      name: "",
      typeLabel: "BUSINESS",
      company: "",
      website: "",
    },
    items: [createEmptyLineItem()],
    taxPercent: 0,
    notes: "Thank you for your business!\nWe appreciate your trust in Sanestix.",
    paymentTerms:
      "Payment is due in full by the due date.\nPlease make the payment via bank transfer or your preferred method.",
    thankYouLine: "Thank you for choosing Sanestix.",
    footerLine: "We look forward to growing together.",
  };
}
SANESTIX_FILE_3_EOF

echo "==> Writing src/lib/invoice-generator/calculations.ts"
cat > "src/lib/invoice-generator/calculations.ts" << 'SANESTIX_FILE_4_EOF'
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
SANESTIX_FILE_4_EOF

echo "==> Writing src/lib/invoice-generator/theme.ts"
cat > "src/lib/invoice-generator/theme.ts" << 'SANESTIX_FILE_5_EOF'
// Colors sampled directly from the reference Sanestix invoice artwork so the
// on-screen preview, the generated PDF and the generated DOCX all match it.
export const invoiceTheme = {
  navy: "#050A30",
  navyDeep: "#06132F",
  cyan: "#00B1F8",
  cyanLight: "#4CCCFF",
  gray: "#6B7280",
  grayLight: "#9AA1AE",
  border: "#E4E7EC",
  tableHeaderText: "#0A1230",
  paper: "#FFFFFF",
};
SANESTIX_FILE_5_EOF

echo "==> Writing src/lib/invoice-generator/pdf-document.tsx"
cat > "src/lib/invoice-generator/pdf-document.tsx" << 'SANESTIX_FILE_6_EOF'
import { Document, Page, View, Text, Svg, Path, StyleSheet } from "@react-pdf/renderer";
import type { InvoiceDocument as InvoiceData } from "./types";
import { computeTotals, formatDateLong, formatMoney, lineItemAmount } from "./calculations";
import { invoiceTheme as t } from "./theme";

const styles = StyleSheet.create({
  page: {
    fontFamily: "Helvetica",
    fontSize: 10,
    color: t.navy,
    paddingBottom: 78,
  },
  body: {
    paddingHorizontal: 42,
    paddingTop: 42,
  },
  headerRow: {
    flexDirection: "row",
    justifyContent: "space-between",
  },
  senderName: {
    fontFamily: "Helvetica-Bold",
    fontSize: 22,
    color: "#0F1222",
  },
  contactRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
    marginTop: 6,
    fontSize: 9.5,
  },
  dot: {
    width: 4,
    height: 4,
    borderRadius: 2,
    backgroundColor: t.cyan,
    marginRight: 2,
  },
  invoiceTitle: {
    fontFamily: "Helvetica-Bold",
    fontSize: 30,
    color: "#0F1222",
    textAlign: "right",
  },
  metaRow: {
    flexDirection: "row",
    justifyContent: "flex-end",
    gap: 6,
    marginTop: 6,
    fontSize: 9.5,
  },
  metaLabel: { color: "#3A3F4C" },
  metaValue: { fontFamily: "Helvetica-Bold" },
  sectionLabel: {
    fontFamily: "Helvetica-Bold",
    fontSize: 9,
    color: t.cyan,
    borderBottomWidth: 1.2,
    borderBottomColor: t.cyan,
    alignSelf: "flex-start",
    paddingBottom: 2,
  },
  billToName: {
    fontFamily: "Helvetica-Bold",
    fontSize: 12,
    marginTop: 8,
  },
  billToMeta: { fontSize: 8.5, color: "#6B7280", marginTop: 3 },
  table: { marginTop: 22 },
  tableHeaderRow: {
    flexDirection: "row",
    backgroundColor: t.cyan,
  },
  tableRow: {
    flexDirection: "row",
    borderBottomWidth: 0.75,
    borderBottomColor: t.border,
  },
  th: { fontFamily: "Helvetica-Bold", fontSize: 9, padding: 7, color: "#0A1230" },
  td: { fontSize: 9.5, padding: 7 },
  colNum: { width: "6%" },
  colDesc: { width: "46%" },
  colQty: { width: "14%", textAlign: "right" },
  colRate: { width: "16%", textAlign: "right" },
  colAmount: { width: "18%", textAlign: "right" },
  bottomRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    marginTop: 26,
  },
  notesBlock: { maxWidth: 260 },
  notesLine: { fontSize: 9.5, color: "#3A3F4C", marginTop: 3 },
  totalsBlock: { width: 220 },
  totalsLine: {
    flexDirection: "row",
    justifyContent: "space-between",
    paddingVertical: 4,
    fontSize: 10.5,
  },
  totalsDivider: { borderTopWidth: 1, borderTopColor: t.border },
  dueLabel: {
    fontFamily: "Helvetica-Bold",
    fontSize: 9,
    color: t.cyan,
    textAlign: "right",
    marginTop: 14,
  },
  dueValue: {
    fontFamily: "Helvetica-Bold",
    fontSize: 18,
    color: "#0F1222",
    textAlign: "right",
    marginTop: 2,
  },
  footer: {
    position: "absolute",
    bottom: 0,
    left: 0,
    right: 0,
    height: 62,
    backgroundColor: t.navyDeep,
    flexDirection: "row",
    alignItems: "center",
    paddingLeft: 38,
  },
  footerHeading: { color: "#FFFFFF", fontFamily: "Helvetica-Bold", fontSize: 11 },
  footerSub: { color: "#C8D3E0", fontSize: 9, marginTop: 2 },
});

export function InvoicePdfDocument({ invoice }: { invoice: InvoiceData }) {
  const totals = computeTotals(invoice.items, invoice.taxPercent);

  return (
    <Document title={`Invoice ${invoice.invoiceNumber}`}>
      <Page size="A4" style={styles.page}>
        {/* Decorative top-right curve */}
        <Svg width="300" height="180" style={{ position: "absolute", top: 0, right: 0 }}>
          <Path d="M300 0H120C210 18 265 80 300 115V0Z" fill={t.navy} opacity={0.92} />
          <Path d="M300 0H165C240 26 285 88 300 130V0Z" fill={t.cyan} />
        </Svg>

        <View style={styles.body}>
          <View style={styles.headerRow}>
            <View style={{ maxWidth: 260 }}>
              <Text style={styles.senderName}>{invoice.sender.name || "Your Company"}</Text>
              <Svg width={100} height={8}>
                <Path d="M2 5C25 -1 75 10 98 3" stroke={t.cyan} strokeWidth={3} fill="none" />
              </Svg>
              {invoice.sender.email ? (
                <View style={styles.contactRow}>
                  <View style={styles.dot} />
                  <Text>{invoice.sender.email}</Text>
                </View>
              ) : null}
              {invoice.sender.phone ? (
                <View style={styles.contactRow}>
                  <View style={styles.dot} />
                  <Text>{invoice.sender.phone}</Text>
                </View>
              ) : null}
              {invoice.sender.addressLine1 || invoice.sender.addressLine2 ? (
                <View style={styles.contactRow}>
                  <View style={styles.dot} />
                  <Text>
                    {[invoice.sender.addressLine1, invoice.sender.addressLine2].filter(Boolean).join(" ")}
                  </Text>
                </View>
              ) : null}
            </View>

            <View>
              <Text style={styles.invoiceTitle}>INVOICE</Text>
              <View style={styles.metaRow}>
                <Text style={styles.metaLabel}>Invoice Number:</Text>
                <Text style={styles.metaValue}>{invoice.invoiceNumber}</Text>
              </View>
              <View style={styles.metaRow}>
                <Text style={styles.metaLabel}>Issue Date:</Text>
                <Text style={styles.metaValue}>{formatDateLong(invoice.issueDate)}</Text>
              </View>
              <View style={styles.metaRow}>
                <Text style={styles.metaLabel}>Due Date:</Text>
                <Text style={styles.metaValue}>{formatDateLong(invoice.dueDate)}</Text>
              </View>
            </View>
          </View>

          {/* Bill to */}
          <View style={{ marginTop: 30 }}>
            <Text style={styles.sectionLabel}>BILL TO</Text>
            <Text style={styles.billToName}>{invoice.client.name || "Client name"}</Text>
            {invoice.client.typeLabel ? <Text style={styles.billToMeta}>{invoice.client.typeLabel}</Text> : null}
            {invoice.client.company ? (
              <Text style={[styles.billToMeta, { color: t.navy, fontSize: 10 }]}>{invoice.client.company}</Text>
            ) : null}
            {invoice.client.website ? <Text style={styles.billToMeta}>{invoice.client.website}</Text> : null}
          </View>

          {/* Table */}
          <View style={styles.table}>
            <View style={styles.tableHeaderRow}>
              <Text style={[styles.th, styles.colNum]}>#</Text>
              <Text style={[styles.th, styles.colDesc]}>Description</Text>
              <Text style={[styles.th, styles.colQty]}>Qty</Text>
              <Text style={[styles.th, styles.colRate]}>Rate</Text>
              <Text style={[styles.th, styles.colAmount]}>Amount</Text>
            </View>
            {invoice.items.map((item, idx) => (
              <View style={styles.tableRow} key={item.id} wrap={false}>
                <Text style={[styles.td, styles.colNum]}>{idx + 1}</Text>
                <Text style={[styles.td, styles.colDesc]}>{item.description || "-"}</Text>
                <Text style={[styles.td, styles.colQty]}>{item.quantity}</Text>
                <Text style={[styles.td, styles.colRate]}>{formatMoney(item.rate, invoice.currency)}</Text>
                <Text style={[styles.td, styles.colAmount]}>
                  {formatMoney(lineItemAmount(item), invoice.currency)}
                </Text>
              </View>
            ))}
          </View>

          {/* Notes + totals */}
          <View style={styles.bottomRow}>
            <View style={styles.notesBlock}>
              {invoice.notes ? (
                <View style={{ marginBottom: 12 }}>
                  <Text style={[styles.sectionLabel, { fontSize: 9.5 }]}>Notes</Text>
                  {invoice.notes.split("\n").map((line, i) => (
                    <Text key={i} style={styles.notesLine}>
                      {line}
                    </Text>
                  ))}
                </View>
              ) : null}
              {invoice.paymentTerms ? (
                <View>
                  <Text style={[styles.sectionLabel, { fontSize: 9.5 }]}>Payment Terms</Text>
                  {invoice.paymentTerms.split("\n").map((line, i) => (
                    <Text key={i} style={styles.notesLine}>
                      {line}
                    </Text>
                  ))}
                </View>
              ) : null}
            </View>

            <View style={styles.totalsBlock}>
              <View style={styles.totalsLine}>
                <Text>Subtotal</Text>
                <Text>{formatMoney(totals.subtotal, invoice.currency)}</Text>
              </View>
              <View style={styles.totalsLine}>
                <Text>Tax ({invoice.taxPercent || 0}%)</Text>
                <Text>{formatMoney(totals.taxAmount, invoice.currency)}</Text>
              </View>
              <View style={[styles.totalsLine, styles.totalsDivider]}>
                <Text style={{ fontFamily: "Helvetica-Bold" }}>Total</Text>
                <Text style={{ fontFamily: "Helvetica-Bold" }}>{formatMoney(totals.total, invoice.currency)}</Text>
              </View>
              <Text style={styles.dueLabel}>TOTAL AMOUNT DUE</Text>
              <Text style={styles.dueValue}>{formatMoney(totals.total, invoice.currency)}</Text>
            </View>
          </View>
        </View>

        <View style={styles.footer} fixed>
          <Svg width={180} height={62} style={{ position: "absolute", right: 0, top: 0 }}>
            <Path d="M180 0H55L180 62V0Z" fill={t.cyan} />
            <Path d="M180 0H100L180 40V0Z" fill={t.cyanLight} />
          </Svg>
          <View>
            <Text style={styles.footerHeading}>{invoice.thankYouLine}</Text>
            <Text style={styles.footerSub}>{invoice.footerLine}</Text>
          </View>
        </View>
      </Page>
    </Document>
  );
}
SANESTIX_FILE_6_EOF

echo "==> Writing src/lib/invoice-generator/docx-document.ts"
cat > "src/lib/invoice-generator/docx-document.ts" << 'SANESTIX_FILE_7_EOF'
import {
  Document,
  Paragraph,
  TextRun,
  Table,
  TableRow,
  TableCell,
  WidthType,
  BorderStyle,
  ShadingType,
  AlignmentType,
  VerticalAlign,
  Footer,
  Packer,
} from "docx";
import type { InvoiceDocument as InvoiceData } from "./types";
import { computeTotals, formatDateLong, formatMoney, lineItemAmount } from "./calculations";
import { invoiceTheme } from "./theme";

const hex = (v: string) => v.replace("#", "");

const NAVY = hex(invoiceTheme.navy);
const NAVY_DEEP = hex(invoiceTheme.navyDeep);
const CYAN = hex(invoiceTheme.cyan);
const GRAY = hex(invoiceTheme.gray);
const BORDER = hex(invoiceTheme.border);
const WHITE = "FFFFFF";

const noBorders = {
  top: { style: BorderStyle.NONE, size: 0, color: WHITE },
  bottom: { style: BorderStyle.NONE, size: 0, color: WHITE },
  left: { style: BorderStyle.NONE, size: 0, color: WHITE },
  right: { style: BorderStyle.NONE, size: 0, color: WHITE },
};

const bottomBorderOnly = {
  top: { style: BorderStyle.NONE, size: 0, color: WHITE },
  bottom: { style: BorderStyle.SINGLE, size: 4, color: BORDER },
  left: { style: BorderStyle.NONE, size: 0, color: WHITE },
  right: { style: BorderStyle.NONE, size: 0, color: WHITE },
};

function cell(children: Paragraph[], opts: Partial<ConstructorParameters<typeof TableCell>[0]> = {}) {
  return new TableCell({
    children,
    borders: noBorders,
    margins: { top: 60, bottom: 60, left: 80, right: 80 },
    verticalAlign: VerticalAlign.TOP,
    ...opts,
  });
}

function line(text: string, opts: { bold?: boolean; size?: number; color?: string; align?: (typeof AlignmentType)[keyof typeof AlignmentType] } = {}) {
  return new Paragraph({
    alignment: opts.align,
    children: [
      new TextRun({
        text,
        bold: opts.bold,
        size: opts.size ?? 20,
        color: opts.color ?? NAVY,
      }),
    ],
  });
}

export async function buildInvoiceDocx(invoice: InvoiceData): Promise<Buffer> {
  const totals = computeTotals(invoice.items, invoice.taxPercent);

  const headerTable = new Table({
    width: { size: 100, type: WidthType.PERCENTAGE },
    rows: [
      new TableRow({
        children: [
          cell(
            [
              line(invoice.sender.name || "Your Company", { bold: true, size: 34 }),
              new Paragraph({
                border: { bottom: { style: BorderStyle.SINGLE, size: 10, color: CYAN, space: 2 } },
                children: [new TextRun({ text: " ", size: 4 })],
              }),
              ...(invoice.sender.email ? [line(invoice.sender.email, { size: 18, color: "3A3F4C" })] : []),
              ...(invoice.sender.phone ? [line(invoice.sender.phone, { size: 18, color: "3A3F4C" })] : []),
              ...(invoice.sender.addressLine1 || invoice.sender.addressLine2
                ? [
                    line(
                      [invoice.sender.addressLine1, invoice.sender.addressLine2].filter(Boolean).join(" "),
                      { size: 18, color: "3A3F4C" }
                    ),
                  ]
                : []),
            ],
            { width: { size: 55, type: WidthType.PERCENTAGE } }
          ),
          cell(
            [
              line("INVOICE", { bold: true, size: 44, align: AlignmentType.RIGHT }),
              new Paragraph({ children: [new TextRun({ text: "", size: 8 })] }),
              metaLine("Invoice Number:", invoice.invoiceNumber),
              metaLine("Issue Date:", formatDateLong(invoice.issueDate)),
              metaLine("Due Date:", formatDateLong(invoice.dueDate)),
            ],
            { width: { size: 45, type: WidthType.PERCENTAGE } }
          ),
        ],
      }),
    ],
  });

  const billTo = [
    new Paragraph({
      border: { bottom: { style: BorderStyle.SINGLE, size: 6, color: CYAN, space: 2 } },
      children: [new TextRun({ text: "BILL TO", bold: true, size: 18, color: CYAN })],
    }),
    line(invoice.client.name || "Client name", { bold: true, size: 24 }),
    ...(invoice.client.typeLabel ? [line(invoice.client.typeLabel, { size: 16, color: GRAY })] : []),
    ...(invoice.client.company ? [line(invoice.client.company, { size: 20 })] : []),
    ...(invoice.client.website ? [line(invoice.client.website, { size: 18, color: GRAY })] : []),
  ];

  const tableHeaderRow = new TableRow({
    tableHeader: true,
    children: [
      headerCell("#", 6),
      headerCell("Description", 46),
      headerCell("Qty", 14, AlignmentType.RIGHT),
      headerCell("Rate", 16, AlignmentType.RIGHT),
      headerCell("Amount", 18, AlignmentType.RIGHT),
    ],
  });

  const itemRows = invoice.items.map(
    (item, idx) =>
      new TableRow({
        children: [
          dataCell(String(idx + 1), 6),
          dataCell(item.description || "-", 46),
          dataCell(String(item.quantity), 14, AlignmentType.RIGHT),
          dataCell(formatMoney(item.rate, invoice.currency), 16, AlignmentType.RIGHT),
          dataCell(formatMoney(lineItemAmount(item), invoice.currency), 18, AlignmentType.RIGHT),
        ],
      })
  );

  const lineItemsTable = new Table({
    width: { size: 100, type: WidthType.PERCENTAGE },
    rows: [tableHeaderRow, ...itemRows],
  });

  const notesColumn: Paragraph[] = [];
  if (invoice.notes) {
    notesColumn.push(
      new Paragraph({ children: [new TextRun({ text: "Notes", bold: true, size: 18, color: CYAN })] }),
      ...invoice.notes.split("\n").map((l) => line(l, { size: 18, color: "3A3F4C" }))
    );
  }
  if (invoice.paymentTerms) {
    if (notesColumn.length) notesColumn.push(new Paragraph({ children: [] }));
    notesColumn.push(
      new Paragraph({ children: [new TextRun({ text: "Payment Terms", bold: true, size: 18, color: CYAN })] }),
      ...invoice.paymentTerms.split("\n").map((l) => line(l, { size: 18, color: "3A3F4C" }))
    );
  }
  if (notesColumn.length === 0) notesColumn.push(new Paragraph({ children: [] }));

  const totalsColumn = [
    totalsLine("Subtotal", formatMoney(totals.subtotal, invoice.currency)),
    totalsLine(`Tax (${invoice.taxPercent || 0}%)`, formatMoney(totals.taxAmount, invoice.currency)),
    totalsLine("Total", formatMoney(totals.total, invoice.currency), true),
    new Paragraph({ children: [new TextRun({ text: "", size: 8 })] }),
    line("TOTAL AMOUNT DUE", { bold: true, size: 16, color: CYAN, align: AlignmentType.RIGHT }),
    line(formatMoney(totals.total, invoice.currency), { bold: true, size: 30, align: AlignmentType.RIGHT }),
  ];

  const bottomTable = new Table({
    width: { size: 100, type: WidthType.PERCENTAGE },
    rows: [
      new TableRow({
        children: [
          cell(notesColumn, { width: { size: 55, type: WidthType.PERCENTAGE } }),
          cell(totalsColumn, { width: { size: 45, type: WidthType.PERCENTAGE } }),
        ],
      }),
    ],
  });

  const footer = new Footer({
    children: [
      new Table({
        width: { size: 100, type: WidthType.PERCENTAGE },
        rows: [
          new TableRow({
            children: [
              new TableCell({
                borders: noBorders,
                margins: { top: 120, bottom: 120, left: 200, right: 200 },
                shading: { type: ShadingType.CLEAR, color: "auto", fill: NAVY_DEEP },
                children: [
                  new Paragraph({
                    children: [new TextRun({ text: invoice.thankYouLine, bold: true, color: WHITE, size: 20 })],
                  }),
                  new Paragraph({
                    children: [new TextRun({ text: invoice.footerLine, color: "C8D3E0", size: 17 })],
                  }),
                ],
              }),
            ],
          }),
        ],
      }),
    ],
  });

  const doc = new Document({
    sections: [
      {
        properties: {},
        footers: { default: footer },
        children: [
          headerTable,
          new Paragraph({ children: [], spacing: { after: 200 } }),
          ...billTo,
          new Paragraph({ children: [], spacing: { after: 200 } }),
          lineItemsTable,
          new Paragraph({ children: [], spacing: { after: 260 } }),
          bottomTable,
        ],
      },
    ],
  });

  return Packer.toBuffer(doc);
}

function metaLine(label: string, value: string) {
  return new Paragraph({
    alignment: AlignmentType.RIGHT,
    children: [
      new TextRun({ text: `${label} `, size: 18, color: "3A3F4C" }),
      new TextRun({ text: value, bold: true, size: 18 }),
    ],
  });
}

function totalsLine(label: string, value: string, bold = false) {
  return new Paragraph({
    tabStops: [{ type: "right", position: 3200 }],
    children: [
      new TextRun({ text: label, bold, size: 20 }),
      new TextRun({ text: `\t${value}`, bold, size: 20 }),
    ],
  });
}

function headerCell(text: string, widthPct: number, align: (typeof AlignmentType)[keyof typeof AlignmentType] = AlignmentType.LEFT) {
  return new TableCell({
    width: { size: widthPct, type: WidthType.PERCENTAGE },
    shading: { type: ShadingType.CLEAR, color: "auto", fill: CYAN },
    margins: { top: 80, bottom: 80, left: 80, right: 80 },
    borders: noBorders,
    children: [new Paragraph({ alignment: align, children: [new TextRun({ text, bold: true, size: 18, color: "0A1230" })] })],
  });
}

function dataCell(text: string, widthPct: number, align: (typeof AlignmentType)[keyof typeof AlignmentType] = AlignmentType.LEFT) {
  return new TableCell({
    width: { size: widthPct, type: WidthType.PERCENTAGE },
    margins: { top: 70, bottom: 70, left: 80, right: 80 },
    borders: bottomBorderOnly,
    children: [new Paragraph({ alignment: align, children: [new TextRun({ text, size: 19 })] })],
  });
}
SANESTIX_FILE_7_EOF

echo "==> Writing src/components/invoice-generator/invoice-preview.tsx"
cat > "src/components/invoice-generator/invoice-preview.tsx" << 'SANESTIX_FILE_8_EOF'
import { Mail, Phone, MapPin, User, Globe2, FileText, CalendarDays, Handshake } from "lucide-react";
import type { InvoiceDocument } from "@/lib/invoice-generator/types";
import { computeTotals, formatDateLong, formatMoney, lineItemAmount } from "@/lib/invoice-generator/calculations";
import { invoiceTheme as t } from "@/lib/invoice-generator/theme";

// Fixed A4-proportioned "paper" (renders at this pixel size, then the parent
// wraps it in a scaling container for smaller screens).
export const INVOICE_SHEET_WIDTH = 794;
export const INVOICE_SHEET_HEIGHT = 1123;

export function InvoicePreview({ doc }: { doc: InvoiceDocument }) {
  const totals = computeTotals(doc.items, doc.taxPercent);

  return (
    <div
      id="invoice-sheet"
      style={{
        width: INVOICE_SHEET_WIDTH,
        minHeight: INVOICE_SHEET_HEIGHT,
        background: t.paper,
        position: "relative",
        overflow: "hidden",
        fontFamily: "Arial, Helvetica, sans-serif",
        color: t.navy,
      }}
    >
      {/* Decorative top-right curve */}
      <svg
        width="340"
        height="220"
        viewBox="0 0 340 220"
        style={{ position: "absolute", top: 0, right: 0, zIndex: 0 }}
      >
        <path d="M340 0H140C240 20 300 90 340 130V0Z" fill={t.navy} opacity="0.92" />
        <path d="M340 0H190C270 30 320 100 340 150V0Z" fill={t.cyan} />
      </svg>

      <div style={{ position: "relative", zIndex: 1, padding: "48px 52px 0 52px" }}>
        {/* Header */}
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
          <div style={{ maxWidth: 300 }}>
            <div style={{ fontSize: 30, fontWeight: 800, letterSpacing: -0.5, color: "#0F1222" }}>
              {doc.sender.name || "Your Company"}
            </div>
            <svg width="120" height="10" viewBox="0 0 120 10" style={{ marginTop: 2 }}>
              <path d="M2 6C30 -2 90 12 118 4" stroke={t.cyan} strokeWidth="4" fill="none" strokeLinecap="round" />
            </svg>
            {doc.sender.tagline && (
              <p style={{ fontSize: 11, color: t.gray, marginTop: 6 }}>{doc.sender.tagline}</p>
            )}

            <div style={{ marginTop: 22, display: "flex", flexDirection: "column", gap: 9 }}>
              {doc.sender.email && (
                <div style={{ display: "flex", alignItems: "center", gap: 9, fontSize: 12 }}>
                  <Mail size={13} color={t.cyan} />
                  <span>{doc.sender.email}</span>
                </div>
              )}
              {doc.sender.phone && (
                <div style={{ display: "flex", alignItems: "center", gap: 9, fontSize: 12 }}>
                  <Phone size={13} color={t.cyan} />
                  <span>{doc.sender.phone}</span>
                </div>
              )}
              {(doc.sender.addressLine1 || doc.sender.addressLine2) && (
                <div style={{ display: "flex", alignItems: "flex-start", gap: 9, fontSize: 12 }}>
                  <MapPin size={13} color={t.cyan} style={{ marginTop: 1, flexShrink: 0 }} />
                  <span>
                    {doc.sender.addressLine1}
                    {doc.sender.addressLine1 && <br />}
                    {doc.sender.addressLine2}
                  </span>
                </div>
              )}
            </div>
          </div>

          <div style={{ textAlign: "right", paddingTop: 6 }}>
            <div style={{ fontSize: 40, fontWeight: 800, color: "#0F1222", letterSpacing: -0.5 }}>INVOICE</div>
            <div style={{ marginTop: 18, display: "flex", flexDirection: "column", gap: 9 }}>
              <MetaRow icon={<FileText size={13} color={t.cyan} />} label="Invoice Number:" value={doc.invoiceNumber} />
              <MetaRow icon={<CalendarDays size={13} color={t.cyan} />} label="Issue Date:" value={formatDateLong(doc.issueDate)} />
              <MetaRow icon={<CalendarDays size={13} color={t.cyan} />} label="Due Date:" value={formatDateLong(doc.dueDate)} />
            </div>
          </div>
        </div>

        {/* Bill To */}
        <div style={{ marginTop: 40 }}>
          <div
            style={{
              fontSize: 11,
              fontWeight: 700,
              color: t.cyan,
              letterSpacing: 1,
              borderBottom: `1.5px solid ${t.cyan}`,
              display: "inline-block",
              paddingBottom: 3,
            }}
          >
            BILL TO
          </div>
          <div style={{ marginTop: 10, display: "flex", alignItems: "center", gap: 7 }}>
            <User size={14} color="#0F1222" />
            <span style={{ fontSize: 14, fontWeight: 700 }}>{doc.client.name || "Client name"}</span>
          </div>
          {doc.client.typeLabel && (
            <div style={{ fontSize: 10, color: t.gray, marginTop: 4, letterSpacing: 0.5 }}>{doc.client.typeLabel}</div>
          )}
          {doc.client.company && <div style={{ fontSize: 12.5, marginTop: 3 }}>{doc.client.company}</div>}
          {doc.client.website && (
            <div style={{ display: "flex", alignItems: "center", gap: 7, fontSize: 12, marginTop: 4, color: t.gray }}>
              <Globe2 size={12} color={t.cyan} />
              <span>{doc.client.website}</span>
            </div>
          )}
        </div>

        {/* Line items table */}
        <div style={{ marginTop: 28 }}>
          <table style={{ width: "100%", borderCollapse: "collapse" }}>
            <thead>
              <tr style={{ background: t.cyan }}>
                <th style={thStyle("6%", "left")}>#</th>
                <th style={thStyle("46%", "left")}>Description</th>
                <th style={thStyle("14%", "right")}>Qty</th>
                <th style={thStyle("16%", "right")}>Rate</th>
                <th style={thStyle("18%", "right")}>Amount</th>
              </tr>
            </thead>
            <tbody>
              {doc.items.map((item, idx) => (
                <tr key={item.id} style={{ borderBottom: `1px solid ${t.border}` }}>
                  <td style={tdStyle("left")}>{idx + 1}</td>
                  <td style={tdStyle("left")}>{item.description || "—"}</td>
                  <td style={tdStyle("right")}>{item.quantity}</td>
                  <td style={tdStyle("right")}>{formatMoney(item.rate, doc.currency)}</td>
                  <td style={tdStyle("right")}>{formatMoney(lineItemAmount(item), doc.currency)}</td>
                </tr>
              ))}
              {doc.items.length === 0 && (
                <tr>
                  <td colSpan={5} style={{ ...tdStyle("left"), color: t.gray, textAlign: "center" }}>
                    No line items yet.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>

        {/* Notes / Terms + Totals */}
        <div style={{ marginTop: 34, display: "flex", justifyContent: "space-between", gap: 24 }}>
          <div style={{ maxWidth: 280 }}>
            {doc.notes && (
              <div style={{ marginBottom: 18 }}>
                <div style={{ fontSize: 11.5, fontWeight: 700, color: t.cyan }}>Notes</div>
                {doc.notes.split("\n").map((line, i) => (
                  <p key={i} style={{ fontSize: 11.5, color: "#3A3F4C", margin: "3px 0 0" }}>
                    {line}
                  </p>
                ))}
              </div>
            )}
            {doc.paymentTerms && (
              <div>
                <div style={{ fontSize: 11.5, fontWeight: 700, color: t.cyan }}>Payment Terms</div>
                {doc.paymentTerms.split("\n").map((line, i) => (
                  <p key={i} style={{ fontSize: 11.5, color: "#3A3F4C", margin: "3px 0 0" }}>
                    {line}
                  </p>
                ))}
              </div>
            )}
          </div>

          <div style={{ width: 250 }}>
            <TotalsRow label="Subtotal" value={formatMoney(totals.subtotal, doc.currency)} />
            <TotalsRow label={`Tax (${doc.taxPercent || 0}%)`} value={formatMoney(totals.taxAmount, doc.currency)} />
            <TotalsRow label="Total" value={formatMoney(totals.total, doc.currency)} bold divider />

            <div style={{ marginTop: 22, textAlign: "right" }}>
              <div style={{ fontSize: 10.5, fontWeight: 700, color: t.cyan, letterSpacing: 0.5 }}>
                TOTAL AMOUNT DUE
              </div>
              <div style={{ fontSize: 24, fontWeight: 800, color: "#0F1222", marginTop: 2 }}>
                {formatMoney(totals.total, doc.currency)}
              </div>
            </div>
          </div>
        </div>

        <div style={{ height: 60 }} />
      </div>

      {/* Bottom banner */}
      <div
        style={{
          position: "absolute",
          bottom: 0,
          left: 0,
          right: 0,
          height: 68,
          background: t.navyDeep,
          display: "flex",
          alignItems: "center",
          overflow: "hidden",
        }}
      >
        <svg
          width="220"
          height="68"
          viewBox="0 0 220 68"
          style={{ position: "absolute", right: 0, top: 0 }}
        >
          <path d="M220 0H70L220 68V0Z" fill={t.cyan} />
          <path d="M220 0H120L220 40V0Z" fill={t.cyanLight} />
        </svg>
        <div style={{ display: "flex", alignItems: "center", gap: 12, paddingLeft: 40, position: "relative", zIndex: 1 }}>
          <Handshake size={22} color={t.cyan} />
          <div>
            <div style={{ fontSize: 13, fontWeight: 700, color: "#fff" }}>{doc.thankYouLine}</div>
            <div style={{ fontSize: 11, color: "#C8D3E0" }}>{doc.footerLine}</div>
          </div>
        </div>
      </div>
    </div>
  );
}

function MetaRow({ icon, label, value }: { icon: React.ReactNode; label: string; value: string }) {
  return (
    <div style={{ display: "flex", alignItems: "center", justifyContent: "flex-end", gap: 8, fontSize: 12 }}>
      {icon}
      <span style={{ color: "#3A3F4C" }}>{label}</span>
      <span style={{ fontWeight: 700, minWidth: 110, textAlign: "left" }}>{value}</span>
    </div>
  );
}

function TotalsRow({
  label,
  value,
  bold,
  divider,
}: {
  label: string;
  value: string;
  bold?: boolean;
  divider?: boolean;
}) {
  return (
    <div
      style={{
        display: "flex",
        justifyContent: "space-between",
        padding: "6px 0",
        borderTop: divider ? `1px solid ${t.border}` : "none",
        fontSize: 13,
        fontWeight: bold ? 700 : 400,
      }}
    >
      <span>{label}</span>
      <span>{value}</span>
    </div>
  );
}

function thStyle(width: string, align: "left" | "right"): React.CSSProperties {
  return {
    width,
    textAlign: align,
    padding: "9px 10px",
    fontSize: 11,
    fontWeight: 700,
    color: "#0A1230",
  };
}

function tdStyle(align: "left" | "right"): React.CSSProperties {
  return {
    textAlign: align,
    padding: "9px 10px",
    fontSize: 12,
    verticalAlign: "top",
  };
}
SANESTIX_FILE_8_EOF

echo "==> Writing src/components/invoice-generator/invoice-generator-client.tsx"
cat > "src/components/invoice-generator/invoice-generator-client.tsx" << 'SANESTIX_FILE_9_EOF'
"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { Plus, Trash2, Download, FileDown, Loader2, RefreshCw } from "lucide-react";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { cn } from "@/lib/utils";
import {
  createEmptyLineItem,
  defaultInvoiceDocument,
  generateInvoiceNumber,
  type InvoiceDocument,
  type InvoiceLineItem,
} from "@/lib/invoice-generator/types";
import { computeTotals, formatMoney } from "@/lib/invoice-generator/calculations";
import { InvoicePreview, INVOICE_SHEET_WIDTH, INVOICE_SHEET_HEIGHT } from "./invoice-preview";

const CURRENCIES = ["PKR", "USD", "EUR", "GBP", "AED", "SAR"];

export function InvoiceGeneratorClient() {
  const [doc, setDoc] = useState<InvoiceDocument>(() => defaultInvoiceDocument());
  const [isDownloadingPdf, setIsDownloadingPdf] = useState(false);
  const [isDownloadingDocx, setIsDownloadingDocx] = useState(false);
  const [downloadError, setDownloadError] = useState<string | null>(null);

  // The invoice number embeds a random suffix — generate it client-side only
  // (after mount) so server-rendered and hydrated markup always match.
  useEffect(() => {
    if (!doc.invoiceNumber) {
      // One-time client-only randomization so SSR and hydrated markup match.
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setDoc((d) => ({ ...d, invoiceNumber: generateInvoiceNumber() }));
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const totals = useMemo(() => computeTotals(doc.items, doc.taxPercent), [doc.items, doc.taxPercent]);

  function patch(partial: Partial<InvoiceDocument>) {
    setDoc((d) => ({ ...d, ...partial }));
  }

  function patchSender(partial: Partial<InvoiceDocument["sender"]>) {
    setDoc((d) => ({ ...d, sender: { ...d.sender, ...partial } }));
  }

  function patchClient(partial: Partial<InvoiceDocument["client"]>) {
    setDoc((d) => ({ ...d, client: { ...d.client, ...partial } }));
  }

  function patchItem(id: string, partial: Partial<InvoiceLineItem>) {
    setDoc((d) => ({
      ...d,
      items: d.items.map((item) => (item.id === id ? { ...item, ...partial } : item)),
    }));
  }

  function addItem() {
    setDoc((d) => ({ ...d, items: [...d.items, createEmptyLineItem()] }));
  }

  function removeItem(id: string) {
    setDoc((d) => ({ ...d, items: d.items.length > 1 ? d.items.filter((i) => i.id !== id) : d.items }));
  }

  async function downloadFile(kind: "pdf" | "docx") {
    const setLoading = kind === "pdf" ? setIsDownloadingPdf : setIsDownloadingDocx;
    setLoading(true);
    setDownloadError(null);
    try {
      const res = await fetch(`/api/invoices/${kind}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(doc),
      });
      if (!res.ok) {
        const body = await res.json().catch(() => null);
        throw new Error(body?.error ?? `Failed to generate ${kind.toUpperCase()}`);
      }
      const blob = await res.blob();
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = `Invoice-${doc.invoiceNumber || "draft"}.${kind}`;
      document.body.appendChild(a);
      a.click();
      a.remove();
      URL.revokeObjectURL(url);
    } catch (err) {
      setDownloadError(err instanceof Error ? err.message : `Failed to generate ${kind.toUpperCase()}`);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="grid grid-cols-1 gap-4 lg:grid-cols-[420px_1fr] lg:items-start">
      {/* ---- Editable form ---- */}
      <Card className="p-6">
        <div className="flex items-start justify-between gap-3">
          <div>
            <CardTitle>Invoice details</CardTitle>
            <CardDescription>Everything here updates the preview live.</CardDescription>
          </div>
          <button
            type="button"
            onClick={() => setDoc(defaultInvoiceDocument())}
            className="flex shrink-0 items-center gap-1.5 border border-outline-variant px-2.5 py-1.5 font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant transition hover:text-on-surface"
            title="Reset to a blank template"
          >
            <RefreshCw size={12} />
            Reset
          </button>
        </div>

        <div className="mt-5 max-h-[calc(100vh-260px)] space-y-6 overflow-y-auto pr-1">
          {/* Invoice meta */}
          <Section title="Invoice">
            <FieldRow>
              <Field label="Invoice number">
                <TextInput value={doc.invoiceNumber} onChange={(v) => patch({ invoiceNumber: v })} />
              </Field>
              <Field label="Currency">
                <select
                  value={doc.currency}
                  onChange={(e) => patch({ currency: e.target.value })}
                  className={inputClass}
                >
                  {CURRENCIES.map((c) => (
                    <option key={c} value={c}>
                      {c}
                    </option>
                  ))}
                </select>
              </Field>
            </FieldRow>
            <FieldRow>
              <Field label="Issue date">
                <input
                  type="date"
                  value={doc.issueDate}
                  onChange={(e) => patch({ issueDate: e.target.value })}
                  className={inputClass}
                />
              </Field>
              <Field label="Due date">
                <input
                  type="date"
                  value={doc.dueDate}
                  onChange={(e) => patch({ dueDate: e.target.value })}
                  className={inputClass}
                />
              </Field>
            </FieldRow>
          </Section>

          {/* Sender */}
          <Section title="From (your business)">
            <Field label="Business name">
              <TextInput value={doc.sender.name} onChange={(v) => patchSender({ name: v })} />
            </Field>
            <FieldRow>
              <Field label="Email">
                <TextInput value={doc.sender.email ?? ""} onChange={(v) => patchSender({ email: v })} />
              </Field>
              <Field label="Phone">
                <TextInput value={doc.sender.phone ?? ""} onChange={(v) => patchSender({ phone: v })} />
              </Field>
            </FieldRow>
            <Field label="Address line 1">
              <TextInput value={doc.sender.addressLine1 ?? ""} onChange={(v) => patchSender({ addressLine1: v })} />
            </Field>
            <Field label="Address line 2">
              <TextInput value={doc.sender.addressLine2 ?? ""} onChange={(v) => patchSender({ addressLine2: v })} />
            </Field>
          </Section>

          {/* Client */}
          <Section title="Bill to (client)">
            <Field label="Client name">
              <TextInput
                value={doc.client.name}
                onChange={(v) => patchClient({ name: v })}
                placeholder="e.g. Syed Nasir Ahmed"
              />
            </Field>
            <FieldRow>
              <Field label="Type label">
                <select
                  value={doc.client.typeLabel ?? ""}
                  onChange={(e) => patchClient({ typeLabel: e.target.value })}
                  className={inputClass}
                >
                  <option value="">None</option>
                  <option value="BUSINESS">Business</option>
                  <option value="INDIVIDUAL">Individual</option>
                </select>
              </Field>
              <Field label="Company">
                <TextInput value={doc.client.company ?? ""} onChange={(v) => patchClient({ company: v })} />
              </Field>
            </FieldRow>
            <Field label="Website">
              <TextInput value={doc.client.website ?? ""} onChange={(v) => patchClient({ website: v })} placeholder="www.example.com" />
            </Field>
          </Section>

          {/* Line items */}
          <Section title="Line items">
            <div className="space-y-3">
              {doc.items.map((item, idx) => (
                <div key={item.id} className="border border-outline-variant p-3">
                  <div className="flex items-center justify-between">
                    <span className="font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant/70">
                      Item {idx + 1}
                    </span>
                    <button
                      type="button"
                      onClick={() => removeItem(item.id)}
                      disabled={doc.items.length === 1}
                      className="text-on-surface-variant transition hover:text-error disabled:cursor-not-allowed disabled:opacity-30"
                    >
                      <Trash2 size={13} />
                    </button>
                  </div>
                  <div className="mt-2">
                    <textarea
                      value={item.description}
                      onChange={(e) => patchItem(item.id, { description: e.target.value })}
                      placeholder="Description of work / product"
                      rows={2}
                      className={cn(inputClass, "resize-none")}
                    />
                  </div>
                  <div className="mt-2 grid grid-cols-3 gap-2">
                    <Field label="Qty" compact>
                      <input
                        type="number"
                        min="0"
                        step="1"
                        value={item.quantity}
                        onChange={(e) => patchItem(item.id, { quantity: Number(e.target.value) })}
                        className={inputClass}
                      />
                    </Field>
                    <Field label="Rate" compact>
                      <input
                        type="number"
                        min="0"
                        step="0.01"
                        value={item.rate}
                        onChange={(e) => patchItem(item.id, { rate: Number(e.target.value) })}
                        className={inputClass}
                      />
                    </Field>
                    <Field label="Amount" compact>
                      <div className={cn(inputClass, "flex items-center bg-surface text-on-surface-variant")}>
                        {formatMoney(item.quantity * item.rate, doc.currency)}
                      </div>
                    </Field>
                  </div>
                </div>
              ))}
            </div>
            <button
              type="button"
              onClick={addItem}
              className="mt-3 flex w-full items-center justify-center gap-1.5 border border-dashed border-outline-variant py-2 font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant transition hover:border-primary hover:text-primary"
            >
              <Plus size={13} />
              Add line item
            </button>

            <Field label="Tax (%)" className="mt-3">
              <input
                type="number"
                min="0"
                max="100"
                step="0.5"
                value={doc.taxPercent}
                onChange={(e) => patch({ taxPercent: Number(e.target.value) })}
                className={inputClass}
              />
            </Field>
          </Section>

          {/* Notes / terms / footer */}
          <Section title="Notes & terms">
            <Field label="Notes">
              <textarea
                value={doc.notes}
                onChange={(e) => patch({ notes: e.target.value })}
                rows={3}
                className={cn(inputClass, "resize-none")}
              />
            </Field>
            <Field label="Payment terms">
              <textarea
                value={doc.paymentTerms}
                onChange={(e) => patch({ paymentTerms: e.target.value })}
                rows={3}
                className={cn(inputClass, "resize-none")}
              />
            </Field>
            <FieldRow>
              <Field label="Footer heading">
                <TextInput value={doc.thankYouLine} onChange={(v) => patch({ thankYouLine: v })} />
              </Field>
              <Field label="Footer subtext">
                <TextInput value={doc.footerLine} onChange={(v) => patch({ footerLine: v })} />
              </Field>
            </FieldRow>
          </Section>
        </div>

        {downloadError && (
          <div className="mt-4 border border-error/30 bg-error-tint px-3 py-2 text-[12px] text-error">
            {downloadError}
          </div>
        )}

        <div className="mt-5 grid grid-cols-2 gap-2">
          <button
            type="button"
            onClick={() => downloadFile("pdf")}
            disabled={isDownloadingPdf}
            className="flex items-center justify-center gap-2 bg-primary px-3 py-2.5 font-mono-data text-[11px] font-medium uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95 disabled:opacity-60"
          >
            {isDownloadingPdf ? <Loader2 size={14} className="animate-spin" /> : <FileDown size={14} />}
            {isDownloadingPdf ? "Building…" : "Download PDF"}
          </button>
          <button
            type="button"
            onClick={() => downloadFile("docx")}
            disabled={isDownloadingDocx}
            className="flex items-center justify-center gap-2 border border-primary px-3 py-2.5 font-mono-data text-[11px] font-medium uppercase tracking-wider text-primary transition hover:bg-primary/10 active:scale-95 disabled:opacity-60"
          >
            {isDownloadingDocx ? <Loader2 size={14} className="animate-spin" /> : <Download size={14} />}
            {isDownloadingDocx ? "Building…" : "Download DOCX"}
          </button>
        </div>
      </Card>

      {/* ---- Live preview ---- */}
      <div className="lg:sticky lg:top-20">
        <ScaledPreview doc={doc} />
        <p className="mt-2 text-center text-[11px] text-on-surface-variant">
          Total due: <span className="font-semibold text-on-surface">{formatMoney(totals.total, doc.currency)}</span>
        </p>
      </div>
    </div>
  );
}

function ScaledPreview({ doc }: { doc: InvoiceDocument }) {
  const containerRef = useRef<HTMLDivElement>(null);
  const [scale, setScale] = useState(1);

  useEffect(() => {
    const el = containerRef.current;
    if (!el) return;
    const observer = new ResizeObserver((entries) => {
      const width = entries[0]?.contentRect.width ?? INVOICE_SHEET_WIDTH;
      setScale(Math.min(1, width / INVOICE_SHEET_WIDTH));
    });
    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  return (
    <div
      ref={containerRef}
      className="w-full overflow-hidden border border-outline-variant bg-[#e9ebef] p-3 sm:p-6"
      style={{ height: INVOICE_SHEET_HEIGHT * scale + 48 }}
    >
      <div
        style={{
          width: INVOICE_SHEET_WIDTH,
          transform: `scale(${scale})`,
          transformOrigin: "top left",
          boxShadow: "0 8px 30px rgba(0,0,0,0.12)",
        }}
      >
        <InvoicePreview doc={doc} />
      </div>
    </div>
  );
}

const inputClass =
  "w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[12.5px] text-on-surface focus:border-primary focus:outline-none";

function TextInput({
  value,
  onChange,
  placeholder,
}: {
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
}) {
  return (
    <input
      type="text"
      value={value}
      onChange={(e) => onChange(e.target.value)}
      placeholder={placeholder}
      className={inputClass}
    />
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div>
      <h4 className="font-mono-data text-[11px] font-semibold uppercase tracking-widest text-on-surface-variant/70">
        {title}
      </h4>
      <div className="mt-2.5 space-y-3">{children}</div>
    </div>
  );
}

function FieldRow({ children }: { children: React.ReactNode }) {
  return <div className="grid grid-cols-2 gap-2">{children}</div>;
}

function Field({
  label,
  children,
  compact,
  className,
}: {
  label: string;
  children: React.ReactNode;
  compact?: boolean;
  className?: string;
}) {
  return (
    <div className={className}>
      <label
        className={cn(
          "mb-1 block font-mono-data uppercase tracking-wider text-on-surface-variant",
          compact ? "text-[9px]" : "text-[11px]"
        )}
      >
        {label}
      </label>
      {children}
    </div>
  );
}
SANESTIX_FILE_9_EOF

echo "==> Writing src/app/finance/invoices/generator/page.tsx"
cat > "src/app/finance/invoices/generator/page.tsx" << 'SANESTIX_FILE_10_EOF'
import { DashboardShell } from "@/components/layout/dashboard-shell";
import { InvoiceGeneratorClient } from "@/components/invoice-generator/invoice-generator-client";

export const dynamic = "force-dynamic";

export default function InvoiceGeneratorPage() {
  return (
    <DashboardShell breadcrumb={["Sanestix OS", "Finance", "Invoices", "Generator"]}>
      <div>
        <h1 className="text-[28px] font-bold tracking-tight text-on-surface">Invoice generator</h1>
        <p className="mt-1 text-[13px] text-on-surface-variant">
          Build a client-ready invoice in the Sanestix brand and export it as a PDF or Word document.
        </p>
      </div>

      <InvoiceGeneratorClient />
    </DashboardShell>
  );
}
SANESTIX_FILE_10_EOF

echo "==> Writing src/app/api/invoices/pdf/route.tsx"
cat > "src/app/api/invoices/pdf/route.tsx" << 'SANESTIX_FILE_11_EOF'
import { NextRequest, NextResponse } from "next/server";
import { renderToBuffer } from "@react-pdf/renderer";
import { InvoicePdfDocument } from "@/lib/invoice-generator/pdf-document";
import type { InvoiceDocument } from "@/lib/invoice-generator/types";

export const runtime = "nodejs";

export async function POST(request: NextRequest) {
  let invoice: InvoiceDocument;
  try {
    invoice = (await request.json()) as InvoiceDocument;
  } catch {
    return NextResponse.json({ error: "Invalid JSON body." }, { status: 400 });
  }

  if (!invoice || !Array.isArray(invoice.items)) {
    return NextResponse.json({ error: "Invalid invoice payload." }, { status: 400 });
  }

  const document = <InvoicePdfDocument invoice={invoice} />;

  let buffer: Buffer;
  try {
    buffer = await renderToBuffer(document);
  } catch (error) {
    console.error("Failed to generate invoice PDF", error);
    return NextResponse.json({ error: "Failed to generate PDF." }, { status: 500 });
  }

  return new NextResponse(new Uint8Array(buffer), {
    status: 200,
    headers: {
      "Content-Type": "application/pdf",
      "Content-Disposition": `attachment; filename="Invoice-${invoice.invoiceNumber || "draft"}.pdf"`,
    },
  });
}
SANESTIX_FILE_11_EOF

echo "==> Writing src/app/api/invoices/docx/route.ts"
cat > "src/app/api/invoices/docx/route.ts" << 'SANESTIX_FILE_12_EOF'
import { NextRequest, NextResponse } from "next/server";
import { buildInvoiceDocx } from "@/lib/invoice-generator/docx-document";
import type { InvoiceDocument } from "@/lib/invoice-generator/types";

export const runtime = "nodejs";

export async function POST(request: NextRequest) {
  let invoice: InvoiceDocument;
  try {
    invoice = (await request.json()) as InvoiceDocument;
  } catch {
    return NextResponse.json({ error: "Invalid JSON body." }, { status: 400 });
  }

  if (!invoice || !Array.isArray(invoice.items)) {
    return NextResponse.json({ error: "Invalid invoice payload." }, { status: 400 });
  }

  let buffer: Buffer;
  try {
    buffer = await buildInvoiceDocx(invoice);
  } catch (error) {
    console.error("Failed to generate invoice DOCX", error);
    return NextResponse.json({ error: "Failed to generate DOCX." }, { status: 500 });
  }

  return new NextResponse(new Uint8Array(buffer), {
    status: 200,
    headers: {
      "Content-Type": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      "Content-Disposition": `attachment; filename="Invoice-${invoice.invoiceNumber || "draft"}.docx"`,
    },
  });
}
SANESTIX_FILE_12_EOF

echo "==> Rebuilding and restarting the container"
if [ -f deploy.sh ]; then
  bash deploy.sh
else
  docker compose build --no-cache
  docker compose up -d
fi

echo ""
echo "Done. Invoice generator is live at: https://dashboard.sanestix.com/finance/invoices/generator"
