import { useState } from "react";
import { NavLink } from "react-router-dom";
import {
  Brain,
  Briefcase,
  ChartLine,
  FlaskConical,
  LayoutDashboard,
  Menu,
  Settings,
  ShieldAlert,
  ShieldCheck,
  ShoppingCart,
  X,
  type LucideIcon,
} from "lucide-react";
import clsx from "clsx";

interface NavItem {
  to: string;
  label: string;
  icon: LucideIcon;
}

interface NavGroup {
  heading: string;
  items: NavItem[];
}

const NAV_GROUPS: NavGroup[] = [
  {
    heading: "Overview",
    items: [{ to: "/dashboard", label: "Dashboard", icon: LayoutDashboard }],
  },
  {
    heading: "Trading",
    items: [
      { to: "/portfolios", label: "Portfolios", icon: Briefcase },
      { to: "/strategies", label: "Strategies", icon: ChartLine },
      { to: "/orders", label: "Orders", icon: ShoppingCart },
    ],
  },
  {
    heading: "Analysis",
    items: [
      { to: "/backtests", label: "Backtests", icon: FlaskConical },
      { to: "/intelligence", label: "Intelligence", icon: Brain },
    ],
  },
  {
    heading: "Risk & Admin",
    items: [
      { to: "/risk", label: "Risk", icon: ShieldAlert },
      { to: "/settings", label: "Settings", icon: Settings },
    ],
  },
];

function BrandMark() {
  return (
    <div className="flex h-14 items-center gap-2 border-b border-slate-200 px-4 text-lg font-semibold text-slate-800">
      <span className="flex h-8 w-8 items-center justify-center rounded-lg bg-gradient-to-br from-brand-600 to-accent-600 text-white">
        <ShieldCheck className="size-5" />
      </span>
      Aegis Trader
    </div>
  );
}

function NavRow({
  item,
  onNavigate,
}: {
  item: NavItem;
  onNavigate?: () => void;
}) {
  const Icon = item.icon;
  return (
    <NavLink
      to={item.to}
      onClick={onNavigate}
      className={({ isActive }) =>
        clsx(
          "group relative flex items-center gap-3 rounded-lg px-3 py-2 text-sm transition",
          isActive
            ? "bg-brand-50 font-medium text-brand-800"
            : "text-slate-600 hover:bg-slate-100 hover:text-slate-900",
        )
      }
    >
      {({ isActive }) => (
        <>
          {isActive && (
            <span
              className="absolute inset-y-1.5 left-0 w-1 rounded-r bg-brand-600"
              aria-hidden="true"
            />
          )}
          <Icon
            className={clsx(
              "size-5 shrink-0",
              isActive
                ? "text-brand-600"
                : "text-slate-400 group-hover:text-slate-500",
            )}
          />
          <span className="flex-1">{item.label}</span>
        </>
      )}
    </NavLink>
  );
}

function SidebarNav({ onNavigate }: { onNavigate?: () => void }) {
  return (
    <nav aria-label="Primary" className="flex-1 space-y-5 overflow-y-auto p-3">
      {NAV_GROUPS.map((group) => (
        <div key={group.heading} className="space-y-0.5">
          <p className="px-3 pb-1 text-[11px] font-semibold uppercase tracking-wider text-slate-400">
            {group.heading}
          </p>
          {group.items.map((item) => (
            <NavRow key={item.to} item={item} onNavigate={onNavigate} />
          ))}
        </div>
      ))}
    </nav>
  );
}

export default function Sidebar() {
  const [mobileOpen, setMobileOpen] = useState(false);

  return (
    <>
      {/* Desktop sidebar */}
      <aside className="hidden w-64 shrink-0 flex-col border-r border-slate-200 bg-white md:flex">
        <BrandMark />
        <SidebarNav />
      </aside>

      {/* Mobile top bar */}
      <div className="fixed inset-x-0 top-0 z-40 flex h-14 items-center gap-2 border-b border-slate-200 bg-white px-4 md:hidden">
        <button
          type="button"
          onClick={() => setMobileOpen(true)}
          className="rounded-md border border-slate-200 p-1.5 text-slate-500 transition hover:bg-slate-50"
          aria-label="Open navigation"
        >
          <Menu className="size-5" />
        </button>
        <ShieldCheck className="size-5 text-brand-600" />
        <span className="text-sm font-semibold text-slate-800">
          Aegis Trader
        </span>
      </div>

      {/* Mobile drawer */}
      {mobileOpen && (
        <div className="fixed inset-0 z-50 md:hidden">
          <div
            className="absolute inset-0 bg-slate-900/40"
            onClick={() => setMobileOpen(false)}
            aria-hidden="true"
          />
          <aside className="absolute inset-y-0 left-0 flex w-64 flex-col border-r border-slate-200 bg-white shadow-xl">
            <div className="flex items-center justify-between">
              <BrandMark />
              <button
                type="button"
                onClick={() => setMobileOpen(false)}
                className="mr-3 rounded-md p-1.5 text-slate-400 transition hover:bg-slate-100"
                aria-label="Close navigation"
              >
                <X className="size-5" />
              </button>
            </div>
            <SidebarNav onNavigate={() => setMobileOpen(false)} />
          </aside>
        </div>
      )}
    </>
  );
}
