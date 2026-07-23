"use client";

import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { StatusPill } from "@/components/ui/status-pill";
import type { ProjectStatusSlice } from "@/lib/types";

const statusColor: Record<ProjectStatusSlice["status"], string> = {
  "On Track": "bg-success",
  "At Risk": "bg-warning",
  Delayed: "bg-error",
  Completed: "bg-on-surface-variant",
};

export function ProjectProgressChart({ data }: { data: ProjectStatusSlice[] }) {
  const total = data.reduce((sum, d) => sum + d.count, 0);

  return (
    <Card className="flex flex-col p-6">
      <div className="mb-6 flex items-start justify-between">
        <div>
          <CardTitle>Project Progress</CardTitle>
          <CardDescription>Status across {total} active projects</CardDescription>
        </div>
        <StatusPill tone="neutral">Projects</StatusPill>
      </div>

      <div className="flex h-3 w-full overflow-hidden">
        {data.map((slice) => (
          <div
            key={slice.status}
            className={statusColor[slice.status]}
            style={{ width: `${(slice.count / total) * 100}%` }}
            title={`${slice.status}: ${slice.count}`}
          />
        ))}
      </div>

      <div className="mt-5 grid grid-cols-2 gap-3">
        {data.map((slice) => (
          <div key={slice.status} className="flex items-center gap-2">
            <span className={`h-2 w-2 ${statusColor[slice.status]}`} />
            <span className="text-[12px] text-on-surface-variant">{slice.status}</span>
            <span className="ml-auto font-mono-data text-[12px] text-on-surface">
              {slice.count}
            </span>
          </div>
        ))}
      </div>
    </Card>
  );
}
