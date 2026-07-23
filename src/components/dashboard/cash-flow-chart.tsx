"use client";

import {
  ResponsiveContainer,
  ComposedChart,
  Bar,
  Line,
  XAxis,
  YAxis,
  Tooltip,
  CartesianGrid,
} from "recharts";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { StatusPill } from "@/components/ui/status-pill";
import { formatCurrency } from "@/lib/utils";
import type { CashFlowPoint } from "@/lib/types";

export function CashFlowChart({ data }: { data: CashFlowPoint[] }) {
  const latestNet = data[data.length - 1].net;

  return (
    <Card className="flex flex-col p-6">
      <div className="mb-6 flex items-start justify-between">
        <div>
          <CardTitle>Cash Flow</CardTitle>
          <CardDescription>Inflow vs. outflow, net position</CardDescription>
        </div>
        <StatusPill tone="success">
          NET {formatCurrency(latestNet, { compact: true })}
        </StatusPill>
      </div>

      <div className="h-[220px] w-full">
        <ResponsiveContainer width="100%" height="100%">
          <ComposedChart data={data} margin={{ top: 8, right: 4, left: 0, bottom: 0 }}>
            <CartesianGrid vertical={false} stroke="#e5e5e5" />
            <XAxis
              dataKey="month"
              tickLine={false}
              axisLine={false}
              tick={{ fontSize: 11, fill: "#666666", fontFamily: "JetBrains Mono, monospace" }}
            />
            <YAxis
              tickLine={false}
              axisLine={false}
              tick={{ fontSize: 10, fill: "#666666", fontFamily: "JetBrains Mono, monospace" }}
              tickFormatter={(v) => formatCurrency(v, { compact: true })}
              width={48}
            />
            <Tooltip
              formatter={(value) => formatCurrency(Number(value))}
              contentStyle={{
                border: "1px solid #e5e5e5",
                borderRadius: 2,
                fontSize: 12,
                fontFamily: "JetBrains Mono, monospace",
              }}
            />
            <Bar dataKey="inflow" fill="#06b6d4" opacity={0.85} barSize={14} />
            <Bar dataKey="outflow" fill="#e5e5e5" barSize={14} />
            <Line
              type="monotone"
              dataKey="net"
              stroke="#000000"
              strokeWidth={1.5}
              dot={{ r: 2 }}
            />
          </ComposedChart>
        </ResponsiveContainer>
      </div>
    </Card>
  );
}
