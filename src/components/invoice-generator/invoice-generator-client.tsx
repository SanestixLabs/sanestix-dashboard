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
