import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";

export interface PnLBarPoint {
  name: string;
  pnl: number;
}

interface PnLBarProps {
  data: PnLBarPoint[];
  height?: number;
}

const PROFIT_COLOR = "#10b981";
const LOSS_COLOR = "#ef4444";

export function PnLBar({ data, height = 320 }: PnLBarProps) {
  return (
    <ResponsiveContainer width="100%" height={height}>
      <BarChart data={data} margin={{ top: 8, right: 16, bottom: 0, left: 0 }}>
        <CartesianGrid
          stroke="#334155"
          strokeDasharray="3 3"
          vertical={false}
        />
        <XAxis
          dataKey="name"
          tick={{ fill: "#94a3b8", fontSize: 12 }}
          stroke="#334155"
          tickLine={false}
        />
        <YAxis
          tick={{ fill: "#94a3b8", fontSize: 12 }}
          stroke="#334155"
          tickLine={false}
          width={80}
        />
        <Tooltip
          contentStyle={{
            backgroundColor: "#1e293b",
            border: "1px solid #334155",
            borderRadius: 8,
          }}
          labelStyle={{ color: "#94a3b8" }}
          itemStyle={{ color: "#f8fafc" }}
          cursor={{ fill: "#334155", fillOpacity: 0.3 }}
        />
        <Bar dataKey="pnl" radius={[4, 4, 0, 0]}>
          {data.map((entry) => (
            <Cell
              key={entry.name}
              fill={entry.pnl >= 0 ? PROFIT_COLOR : LOSS_COLOR}
            />
          ))}
        </Bar>
      </BarChart>
    </ResponsiveContainer>
  );
}
