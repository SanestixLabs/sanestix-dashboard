import path from "node:path";
import { Document, Page, View, Text, Image, Svg, Path, StyleSheet } from "@react-pdf/renderer";
import type { InvoiceDocument as InvoiceData } from "./types";
import { computeTotals, formatDateLong, formatMoney, lineItemAmount } from "./calculations";
import { invoiceTheme as t } from "./theme";

// Actual brand logo (public/sanestix-logo.png), read from the standalone
// server's copy of /public — swapped in for the old text+squiggle
// placeholder that used to stand in for "Sanestix".
const LOGO_PATH = path.join(process.cwd(), "public", "sanestix-logo.png");
// Source logo is 1028x824 (aspect ratio ~1.248:1) — width fixed, height
// derived so it never distorts regardless of react-pdf's Image sizing.
const LOGO_WIDTH = 118;
const LOGO_HEIGHT = Math.round(LOGO_WIDTH / 1.248);

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
        {/* Decorative top-right corner accent. Capped at 32pt tall — well
            under body.paddingTop (42) — so it can never overlap the
            invoice title/meta text below it, at any width. */}
        <Svg width="220" height="32" style={{ position: "absolute", top: 0, right: 0 }}>
          <Path d="M220 0H60L220 30Z" fill={t.navy} opacity={0.92} />
          <Path d="M220 0H130L220 20Z" fill={t.cyan} />
        </Svg>

        <View style={styles.body}>
          <View style={styles.headerRow}>
            <View style={{ maxWidth: 260 }}>
              {/* eslint-disable-next-line jsx-a11y/alt-text -- this is @react-pdf/renderer's Image, not an HTML img */}
              <Image src={LOGO_PATH} style={{ width: LOGO_WIDTH, height: LOGO_HEIGHT, marginBottom: 4 }} />
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
