import Link from "next/link";
import { ArrowDownCircle, ArrowUpCircle } from "lucide-react";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { cn, formatCurrency, formatRelativeDate } from "@/lib/utils";
import type { UpcomingPayment } from "@/lib/types";

const SOURCE_LABEL: Record<UpcomingPayment["source"], string> = {
  invoice: "Invoice",
  debt: "Debt",
  subscription: "Subscription",
};

const SOURCE_HREF: Record<UpcomingPayment["source"], string> = {
  invoice: "/finance/invoices",
  debt: "/finance/debts",
  subscription: "/finance/subscriptions",
};

const MAX_ROWS = 6;

function PaymentRow({ payment }: { payment: UpcomingPayment }) {
  const { label: dueLabel } = formatRelativeDate(payment.dueDate);

  return (
    <Link
      href={SOURCE_HREF[payment.source]}
      className="flex items-center justify-between gap-3 border-b border-outline-variant px-4 py-2.5 transition-colors last:border-b-0 hover:bg-background"
    >
      <div className="min-w-0">
        <p className="truncate text-[13px] text-on-surface">{payment.label}</p>
        <p className="font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant/70">
          {SOURCE_LABEL[payment.source]}
        </p>
      </div>
      <div className="shrink-0 text-right">
        <p className="font-mono-data text-[13px] font-medium text-on-surface">
          {formatCurrency(payment.amount, { compact: true })}
        </p>
        <p
          className={cn(
            "font-mono-data text-[10px] uppercase tracking-wider",
            payment.overdue ? "text-error" : "text-on-surface-variant/70"
          )}
        >
          {dueLabel}
        </p>
      </div>
    </Link>
  );
}

function PaymentColumn({
  title,
  description,
  icon,
  iconClass,
  totalLabel,
  total,
  payments,
  emptyMessage,
}: {
  title: string;
  description: string;
  icon: React.ReactNode;
  iconClass: string;
  totalLabel: string;
  total: number;
  payments: UpcomingPayment[];
  emptyMessage: string;
}) {
  const overflow = payments.length - MAX_ROWS;

  return (
    <Card className="flex flex-col p-0">
      <div className="flex items-start justify-between gap-3 p-4">
        <div className="flex items-center gap-3">
          <span className={iconClass}>{icon}</span>
          <div>
            <CardTitle>{title}</CardTitle>
            <CardDescription className="mt-0.5">{description}</CardDescription>
          </div>
        </div>
        <div className="shrink-0 text-right">
          <p className="font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant/70">
            {totalLabel}
          </p>
          <p className={cn("text-[18px] font-bold leading-tight", iconClass)}>
            {formatCurrency(total, { compact: true })}
          </p>
        </div>
      </div>

      {payments.length === 0 ? (
        <p className="border-t border-outline-variant px-4 py-6 text-center text-[13px] text-on-surface-variant">
          {emptyMessage}
        </p>
      ) : (
        <div className="border-t border-outline-variant">
          {payments.slice(0, MAX_ROWS).map((payment) => (
            <PaymentRow key={payment.id} payment={payment} />
          ))}
          {overflow > 0 && (
            <p className="border-t border-outline-variant px-4 py-2 text-center font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
              +{overflow} more
            </p>
          )}
        </div>
      )}
    </Card>
  );
}

export function UpcomingPayments({
  due,
  toReceive,
}: {
  due: UpcomingPayment[];
  toReceive: UpcomingPayment[];
}) {
  const totalDue = due.reduce((sum, p) => sum + p.amount, 0);
  const totalToReceive = toReceive.reduce((sum, p) => sum + p.amount, 0);

  return (
    <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
      <PaymentColumn
        title="Due"
        description="Debts and subscription renewals, next 30 days"
        icon={<ArrowUpCircle size={18} />}
        iconClass="text-error"
        totalLabel="Total Due"
        total={totalDue}
        payments={due}
        emptyMessage="Nothing due in the next 30 days."
      />
      <PaymentColumn
        title="To Receive"
        description="Unpaid invoices, next 30 days"
        icon={<ArrowDownCircle size={18} />}
        iconClass="text-success"
        totalLabel="Total to Receive"
        total={totalToReceive}
        payments={toReceive}
        emptyMessage="No invoices due in the next 30 days."
      />
    </div>
  );
}
