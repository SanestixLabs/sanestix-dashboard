import fs from "node:fs";
import path from "node:path";
import {
  Document,
  Paragraph,
  TextRun,
  ImageRun,
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

// Same brand logo used by the PDF export and the on-screen preview.
// Aspect ratio ~1.248:1 (1028x824 source) — width fixed, height derived.
const LOGO_PATH = path.join(process.cwd(), "public", "sanestix-logo.png");
const LOGO_WIDTH = 130;
const LOGO_HEIGHT = Math.round(LOGO_WIDTH / 1.248);

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
              new Paragraph({
                children: [
                  new ImageRun({
                    data: fs.readFileSync(LOGO_PATH),
                    transformation: { width: LOGO_WIDTH, height: LOGO_HEIGHT },
                    type: "png",
                  }),
                ],
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
