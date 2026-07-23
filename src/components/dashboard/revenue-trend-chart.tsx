"use client";

import {
  ResponsiveContainer,
  AreaChart,
  Area,
  XAxis,
  YAxis,
  Tooltip,
  CartesianGrid,
} from "recharts";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { StatusPill } from "@/components/ui/status-pill";
import { formatCurrency } from "@/lib/utils";
import type { RevenuePoint } from "@/lib/types";

export function RevenueTrendChart({ data }: { data: RevenuePoint[] }) {
  const latest = data[data.length - 1];
  const first = data[0];
  const pctChange =
    first?.revenue > 0 ? (((latest.revenue - first.revenue) / first.revenue) * 100).toFixed(1) : null;

  return (
    <Card className="col-span-2 flex flex-col p-6">
      <div className="mb-6 flex items-start justify-between">
        <div>
          <CardTitle>Revenue Trend</CardTitle>
          <CardDescription>Monthly revenue vs. operating expenses</CardDescription>
        </div>
        <div className="flex gap-2">
          <StatusPill tone="primary">{pctChange ? `+${pctChange}% 6MO` : "NEW DATA"}</StatusPill>
          <StatusPill tone="neutral">Finance</StatusPill>
        </div>
      </div>

      <div className="h-[280px] w-full">
        <ResponsiveContainer width="100%" height="100%">
          <AreaChart data={data} margin={{ top: 8, right: 8, left: 0, bottom: 0 }}>
            <defs>
              <linearGradient id="revenueFill" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="#06b6d4" stopOpacity={0.18} />
                <stop offset="100%" stopColor="#06b6d4" stopOpacity={0} />
              </linearGradient>
            </defs>
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
              tick={{ fontSize: 11, fill: "#666666", fontFamily: "JetBrains Mono, monospace" }}
              tickFormatter={(v) => formatCurrency(v, { compact: true })}
              width={56}
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
            <Area
              type="monotone"
              dataKey="expenses"
              stroke="#666666"
              strokeWidth={1.5}
              fill="transparent"
              strokeDasharray="3 3"
            />
            <Area
              type="monotone"
              dataKey="revenue"
              stroke="#06b6d4"
              strokeWidth={2.5}
              fill="url(#revenueFill)"
            />
          </AreaChart>
        </ResponsiveContainer>
      </div>
    </Card>
  );
}
