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
