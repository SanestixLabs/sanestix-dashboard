import { InvoiceGeneratorClient } from "@/components/invoice-generator/invoice-generator-client";

export const dynamic = "force-dynamic";

export default function InvoiceGeneratorPage() {
  return (
    <>
      <div>
        <h1 className="text-[28px] font-bold tracking-tight text-on-surface">Invoice generator</h1>
        <p className="mt-1 text-[13px] text-on-surface-variant">
          Build a client-ready invoice in the Sanestix brand and export it as a PDF or Word document.
        </p>
      </div>

      <InvoiceGeneratorClient />
    </>
  );
}
