// Domain types for Sanestix OS — Phase 1 modules (Finance, Projects, CRM)
// These mirror the shape the FastAPI backend is expected to return per
// Sanestix-OS-Roadmap.md §1.5 (Executive Dashboard, real data from
// Finance + Projects + CRM). Swap `lib/data.ts` for real fetch calls
// against these same shapes when the backend ships.

export type TrendDirection = "up" | "down" | "flat";

export interface KpiCard {
  id: string;
  label: string;
  value: string;
  unit?: string;
  delta?: string;
  trend?: TrendDirection;
  tone?: "primary" | "neutral" | "success" | "warning" | "error";
  sourceModule: "finance" | "projects" | "crm";
}

export interface RevenuePoint {
  month: string;
  revenue: number;
  expenses: number;
}

export interface CashFlowPoint {
  month: string;
  inflow: number;
  outflow: number;
  net: number;
}

export interface FunnelStage {
  stage: string;
  count: number;
}

export interface ProjectStatusSlice {
  status: "On Track" | "At Risk" | "Delayed" | "Completed";
  count: number;
}

export type ActivityKind =
  | "invoice_due"
  | "invoice_paid"
  | "task_overdue"
  | "project_delay"
  | "lead_new"
  | "meeting_booked";

export interface ActivityItem {
  id: string;
  kind: ActivityKind;
  title: string;
  detail: string;
  timestamp: string; // relative label, e.g. "2m ago"
  module: "finance" | "projects" | "crm";
}

export interface DashboardData {
  kpis: KpiCard[];
  revenueTrend: RevenuePoint[];
  cashFlow: CashFlowPoint[];
  salesFunnel: FunnelStage[];
  projectStatus: ProjectStatusSlice[];
  activity: ActivityItem[];
  generatedAt: string;
}

// ---------------------------------------------------------------------------
// Transactions + Invoices — the raw ledger behind the Overview KPIs/charts.
// ---------------------------------------------------------------------------

export type TransactionKind = "revenue" | "expense";

export interface Transaction {
  id: string;
  occurredOn: string;
  kind: TransactionKind;
  category: string | null;
  amount: number;
  note: string | null;
  proofUrl: string | null;
  createdByName: string | null;
}

export type InvoiceStatus = "outstanding" | "paid" | "overdue";

export interface Invoice {
  id: string;
  clientName: string;
  amount: number;
  status: InvoiceStatus;
  dueDate: string;
  proofUrl: string | null;
  createdByName: string | null;
}

// ---------------------------------------------------------------------------
// Founder loans + profit distribution ("loan recovery" / "profit split")
// ---------------------------------------------------------------------------

export interface Founder {
  id: string;
  fullName: string | null;
}

export type LoanDirection = "loan_in" | "repayment_out";

export interface LoanEntry {
  id: string;
  founderId: string;
  founderName: string | null;
  occurredOn: string;
  description: string;
  direction: LoanDirection;
  amount: number;
}

export interface LoanBalance {
  founderId: string;
  founderName: string | null;
  totalLoaned: number;
  totalRepaid: number;
  outstanding: number;
}

export interface ProfitDistribution {
  id: string;
  periodMonth: string;
  grossProfit: number;
  capitalReserve: number;
  loanRepayment: number;
  distributableProfit: number;
  charityPct: number;
  charityAmount: number;
  perFounderAmount: number;
  note: string | null;
  createdAt: string;
}

export interface ProfitSplitSuggestion {
  periodMonth: string;
  grossProfit: number;
  outstandingLoanBalance: number;
}

// ---------------------------------------------------------------------------
// Phase 2 registers — Vendors, Subscriptions, Assets, Debts, Employees
// ---------------------------------------------------------------------------

export type VendorStatus = "active" | "inactive";

export interface Vendor {
  id: string;
  name: string;
  category: string | null;
  contactPerson: string | null;
  contactEmail: string | null;
  paymentTerms: string | null;
  status: VendorStatus;
  notes: string | null;
  createdByName: string | null;
  createdAt: string;
}

export type BillingCycle = "monthly" | "annual";
export type SubscriptionStatus = "active" | "cancelled";

export interface Subscription {
  id: string;
  vendorName: string;
  cost: number;
  billingCycle: BillingCycle;
  renewalDate: string | null;
  owner: string | null;
  status: SubscriptionStatus;
  notes: string | null;
  proofUrl: string | null;
  createdByName: string | null;
  createdAt: string;
}

export type AssetCondition = "new" | "good" | "fair" | "poor" | "disposed";

export interface Asset {
  id: string;
  name: string;
  purchaseDate: string;
  cost: number;
  owner: string | null;
  condition: AssetCondition;
  serialNumber: string | null;
  notes: string | null;
  proofUrl: string | null;
  createdByName: string | null;
  createdAt: string;
}

export type DebtStatus = "outstanding" | "paid" | "overdue";

export interface Debt {
  id: string;
  counterparty: string;
  principal: number;
  paidAmount: number;
  remainingBalance: number;
  dueDate: string | null;
  status: DebtStatus;
  notes: string | null;
  proofUrl: string | null;
  createdByName: string | null;
  createdAt: string;
}

export type EmployeeStatus = "active" | "inactive";

export interface Employee {
  id: string;
  fullName: string;
  role: string | null;
  salary: number | null;
  startDate: string | null;
  status: EmployeeStatus;
  payDay: number | null;
  notes: string | null;
  createdByName: string | null;
  createdAt: string;
}

// ---------------------------------------------------------------------------
// Upcoming payments — combined view of money due out (debts, subscription
// renewals) vs. money due in (unpaid invoices), for the Finance overview.
// ---------------------------------------------------------------------------

export type UpcomingPaymentDirection = "due" | "to_receive";
export type UpcomingPaymentSource = "invoice" | "debt" | "subscription" | "employee";

export interface UpcomingPayment {
  id: string;
  direction: UpcomingPaymentDirection;
  source: UpcomingPaymentSource;
  label: string;
  amount: number;
  dueDate: string;
  overdue: boolean;
}

// ---------------------------------------------------------------------------
// Employee salary payments — payroll history with optional proof-of-payment
// image, so each payday can be marked paid and audited later.
// ---------------------------------------------------------------------------

export interface EmployeePayment {
  id: string;
  employeeId: string;
  employeeName: string | null;
  amount: number;
  payPeriod: string; // first day of the month this payment covers, e.g. "2026-07-01"
  paidOn: string;
  proofUrl: string | null;
  notes: string | null;
  createdByName: string | null;
  createdAt: string;
}

// ---------------------------------------------------------------------------
// CRM — Companies, Contacts, Leads (pipeline), activity log, follow-up tasks.
// A "won" lead auto-creates a draft Project (see app/crm/actions.ts), which
// is the real cross-module link the roadmap calls for.
// ---------------------------------------------------------------------------

export interface CrmCompany {
  id: string;
  name: string;
  industry: string | null;
  website: string | null;
  notes: string | null;
  contactCount: number;
  leadCount: number;
  createdByName: string | null;
  createdAt: string;
}

export interface CrmContact {
  id: string;
  companyId: string | null;
  companyName: string | null;
  fullName: string;
  email: string | null;
  phone: string | null;
  title: string | null;
  notes: string | null;
  createdByName: string | null;
  createdAt: string;
}

export type LeadStage =
  | "new"
  | "attempted_contact"
  | "connected"
  | "qualified"
  | "discovery_scheduled"
  | "discovery_completed"
  | "demo_scheduled"
  | "demo_completed"
  | "proposal_sent"
  | "negotiation"
  | "contract_sent"
  | "won"
  | "lost"
  | "nurture";

export const LEAD_STAGES: { value: LeadStage; label: string }[] = [
  { value: "new", label: "New" },
  { value: "attempted_contact", label: "Attempted Contact" },
  { value: "connected", label: "Connected" },
  { value: "qualified", label: "Qualified" },
  { value: "discovery_scheduled", label: "Discovery Scheduled" },
  { value: "discovery_completed", label: "Discovery Completed" },
  { value: "demo_scheduled", label: "Demo Scheduled" },
  { value: "demo_completed", label: "Demo Completed" },
  { value: "proposal_sent", label: "Proposal Sent" },
  { value: "negotiation", label: "Negotiation" },
  { value: "contract_sent", label: "Contract Sent" },
  { value: "won", label: "Won" },
  { value: "lost", label: "Lost" },
  { value: "nurture", label: "Nurture" },
];

export type LeadPriority = "low" | "medium" | "high" | "urgent";

export const LEAD_PRIORITIES: { value: LeadPriority; label: string }[] = [
  { value: "low", label: "Low" },
  { value: "medium", label: "Medium" },
  { value: "high", label: "High" },
  { value: "urgent", label: "Urgent" },
];

// Shown as a dropdown when a lead is marked "lost", so win/loss reporting
// on the CRM pipeline page has something more useful than a raw count.
export const LOST_REASONS = [
  "Budget",
  "Timing",
  "Went with a competitor",
  "No response / went cold",
  "Not a good fit",
  "Other",
] as const;

export interface CrmLead {
  id: string;
  title: string;
  companyId: string | null;
  companyName: string | null;
  contactId: string | null;
  contactName: string | null;
  contactEmail: string | null;
  stage: LeadStage;
  value: number;
  source: string | null;
  ownerId: string | null;
  ownerName: string | null;
  expectedCloseDate: string | null;
  notes: string | null;
  lostReason: string | null;
  convertedProjectId: string | null;
  industry: string | null;
  website: string | null;
  phone: string | null;
  email: string | null;
  address: string | null;
  city: string | null;
  state: string | null;
  country: string | null;
  timezone: string | null;
  employeesCount: number | null;
  revenueEstimate: number | null;
  googleRating: number | null;
  reviewCount: number | null;
  currentCrm: string | null;
  currentReceptionist: string | null;
  priority: LeadPriority;
  leadScore: number;
  tags: string[];
  openTaskCount: number;
  overdueTaskCount: number;
  createdByName: string | null;
  createdAt: string;
  updatedAt: string;
}

export type LeadActivityKind = "note" | "call" | "email" | "meeting" | "stage_change";

export interface CrmLeadActivity {
  id: string;
  leadId: string;
  kind: LeadActivityKind;
  content: string;
  createdByName: string | null;
  createdAt: string;
}

export interface CrmLeadTask {
  id: string;
  leadId: string;
  leadTitle: string | null;
  title: string;
  dueDate: string;
  done: boolean;
  overdue: boolean;
  createdByName: string | null;
  createdAt: string;
}

// ---------------------------------------------------------------------------
// Projects — minimal real table. Grows later (tasks, members, comments)
// without changing this shape; a project can optionally trace back to the
// lead that became it.
// ---------------------------------------------------------------------------

export type ProjectRowStatus = "on_track" | "at_risk" | "delayed" | "completed";

export interface Project {
  id: string;
  name: string;
  clientName: string | null;
  companyId: string | null;
  companyName: string | null;
  status: ProjectRowStatus;
  sourceLeadId: string | null;
  sourceLeadTitle: string | null;
  notes: string | null;
  createdByName: string | null;
  createdAt: string;
}

// ---------------------------------------------------------------------------
// Projects — Kanban detail (tasks, assignees, comments). Separate from the
// lightweight `Project` row type used by the /projects list page; this is
// the richer shape used by the /projects/[id] detail page + task board.
// ---------------------------------------------------------------------------

export type TaskStatus = "backlog" | "todo" | "in_progress" | "review" | "done";
export type TaskPriority = "low" | "medium" | "high" | "urgent";

// A small fixed tag palette (Jira "labels" / ClickUp "tags") rather than
// free-form text, so the board filter dropdown stays a clean, known list
// instead of every task inventing its own one-off tag.
export const TASK_LABELS = [
  "Bug",
  "Feature",
  "Design",
  "Client Request",
  "Tech Debt",
  "Blocked",
] as const;

export interface ProjectPerson {
  id: string;
  fullName: string | null;
}

export interface TaskComment {
  id: string;
  taskId: string;
  authorName: string | null;
  body: string;
  createdAt: string;
}

export interface ProjectTask {
  id: string;
  projectId: string;
  title: string;
  description: string | null;
  status: TaskStatus;
  priority: TaskPriority;
  dueDate: string | null;
  labels: string[];
  position: number;
  assignees: ProjectPerson[];
  comments: TaskComment[];
  createdByName: string | null;
  createdAt: string;
}

// A task assigned to the current user, with enough project context to jump
// straight to it — the data behind the cross-project "My Tasks" panel on
// the Projects list page (the ClickUp/Jira "My Work" equivalent).
export interface MyTask {
  id: string;
  projectId: string;
  projectName: string;
  title: string;
  status: TaskStatus;
  priority: TaskPriority;
  dueDate: string | null;
  overdue: boolean;
  labels: string[];
}

export interface ProjectDetail {
  id: string;
  name: string;
  clientName: string | null;
  description: string | null;
  status: ProjectRowStatus;
  ownerId: string | null;
  ownerName: string | null;
  startDate: string | null;
  endDate: string | null;
  budget: number | null;
  taskCount: number;
  doneTaskCount: number;
  overdueTaskCount: number;
  createdAt: string;
}
