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
