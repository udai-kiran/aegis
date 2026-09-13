import {
  Cell,
  Legend,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
} from "recharts";

export interface AllocationSlice {
  name: string;
  value: number;
}

interface AllocationPieProps {
  data: AllocationSlice[];
  height?: number;
}

const SLICE_COLORS = [
  "#3b82f6",
  "#10b981",
  "#f59e0b",
  "#8b5cf6",
  "#06b6d4",
  "#ef4444",
  "#f472b6",
  "#a3e635",
];

export function AllocationPie({ data, height = 320 }: AllocationPieProps) {
  return (
    <ResponsiveContainer width="100%" height={height}>
      <PieChart>
        <Pie
          data={data}
          dataKey="value"
          nameKey="name"
          cx="50%"
          cy="50%"
          outerRadius="70%"
          label={({ name, percent }) =>
            `${name} ${((percent ?? 0) * 100).toFixed(0)}%`
          }
          labelLine={{ stroke: "#334155" }}
        >
          {data.map((entry, index) => (
            <Cell
              key={entry.name}
              fill={SLICE_COLORS[index % SLICE_COLORS.length]}
            />
          ))}
        </Pie>
        <Tooltip
          contentStyle={{
            backgroundColor: "#1e293b",
            border: "1px solid #334155",
            borderRadius: 8,
          }}
          labelStyle={{ color: "#94a3b8" }}
          itemStyle={{ color: "#f8fafc" }}
        />
        <Legend wrapperStyle={{ color: "#94a3b8", fontSize: 12 }} />
      </PieChart>
    </ResponsiveContainer>
  );
}
