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
