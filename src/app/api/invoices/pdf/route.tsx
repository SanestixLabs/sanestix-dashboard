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
