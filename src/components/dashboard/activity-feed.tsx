import {
  Receipt,
  AlertTriangle,
  UserPlus,
  CheckCircle2,
  CalendarClock,
  Clock,
} from "lucide-react";
import { Card } from "@/components/ui/card";
import type { ActivityItem, ActivityKind } from "@/lib/types";

const iconMap: Record<ActivityKind, React.ElementType> = {
  invoice_due: Receipt,
  invoice_paid: CheckCircle2,
  task_overdue: AlertTriangle,
  project_delay: Clock,
  lead_new: UserPlus,
  meeting_booked: CalendarClock,
};

const toneMap: Record<ActivityKind, string> = {
  invoice_due: "text-warning",
  invoice_paid: "text-success",
  task_overdue: "text-error",
  project_delay: "text-warning",
  lead_new: "text-primary",
  meeting_booked: "text-on-surface-variant",
};

export function ActivityFeed({ items }: { items: ActivityItem[] }) {
  return (
    <Card className="flex flex-col">
      <div className="flex items-center justify-between border-b border-outline-variant p-5">
        <h3 className="text-[11px] font-mono-data uppercase tracking-widest text-on-surface">
          Recent Activity
        </h3>
        <span className="text-[10px] font-mono-data text-on-surface-variant/60">
          LIVE
        </span>
      </div>
      <div className="flex-1 divide-y divide-outline-variant/60">
        {items.map((item) => {
          const Icon = iconMap[item.kind];
          return (
            <div
              key={item.id}
              className="group flex cursor-pointer gap-3 p-4 transition-colors hover:bg-background"
            >
              <Icon size={15} className={`mt-0.5 ${toneMap[item.kind]}`} />
              <div className="flex-1">
                <div className="flex items-baseline justify-between gap-2">
                  <span className="text-[12.5px] font-semibold text-on-surface">
                    {item.title}
                  </span>
                  <span className="whitespace-nowrap text-[10px] text-on-surface-variant/70">
                    {item.timestamp}
                  </span>
                </div>
                <p className="mt-0.5 text-[12px] text-on-surface-variant">
                  {item.detail}
                </p>
              </div>
            </div>
          );
        })}
      </div>
    </Card>
  );
}
