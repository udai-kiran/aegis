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

const NAV_ITEMS: NavItem[] = [
  { to: "/dashboard", label: "Dashboard", icon: LayoutDashboard },
  { to: "/portfolios", label: "Portfolios", icon: Briefcase },
  { to: "/strategies", label: "Strategies", icon: ChartLine },
  { to: "/backtests", label: "Backtests", icon: FlaskConical },
  { to: "/orders", label: "Orders", icon: ShoppingCart },
  { to: "/risk", label: "Risk", icon: ShieldAlert },
  { to: "/intelligence", label: "Intelligence", icon: Brain },
  { to: "/settings", label: "Settings", icon: Settings },
];

function Logo() {
  return (
    <div className="flex items-center gap-2 px-4 py-4">
      <ShieldCheck className="size-6 text-brand-400" />
      <span className="text-base font-semibold text-slate-50">
        Aegis Trader
      </span>
    </div>
  );
}

function NavLinks({ onNavigate }: { onNavigate?: () => void }) {
  return (
    <nav className="flex-1 space-y-1 overflow-y-auto px-2 py-2">
      {NAV_ITEMS.map(({ to, label, icon: Icon }) => (
        <NavLink
          key={to}
          to={to}
          onClick={onNavigate}
          className={({ isActive }) =>
            clsx(
              "flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition-colors",
              isActive
                ? "bg-surface-2 text-brand-400"
                : "text-slate-400 hover:bg-surface-2 hover:text-slate-50",
            )
          }
        >
          <Icon className="size-4" />
          {label}
        </NavLink>
      ))}
    </nav>
  );
}

export default function Sidebar() {
  const [mobileOpen, setMobileOpen] = useState(false);

  return (
    <>
      {/* Desktop sidebar */}
      <aside className="fixed inset-y-0 left-0 hidden w-64 flex-col border-r border-surface-3 bg-surface-1 md:flex">
        <div className="border-b border-surface-3">
          <Logo />
        </div>
        <NavLinks />
      </aside>

      {/* Mobile top bar */}
      <div className="fixed inset-x-0 top-0 z-40 flex h-14 items-center gap-2 border-b border-surface-3 bg-surface-1 px-4 md:hidden">
        <button
          type="button"
          onClick={() => setMobileOpen(true)}
          className="rounded-md p-1.5 text-slate-400 transition-colors hover:bg-surface-2 hover:text-slate-50"
          aria-label="Open navigation"
        >
          <Menu className="size-5" />
        </button>
        <ShieldCheck className="size-5 text-brand-400" />
        <span className="text-sm font-semibold text-slate-50">
          Aegis Trader
        </span>
      </div>

      {/* Mobile drawer */}
      {mobileOpen && (
        <div className="fixed inset-0 z-50 md:hidden">
          <div
            className="absolute inset-0 bg-black/60"
            onClick={() => setMobileOpen(false)}
            aria-hidden="true"
          />
          <aside className="absolute inset-y-0 left-0 flex w-64 flex-col border-r border-surface-3 bg-surface-1">
            <div className="flex items-center justify-between border-b border-surface-3">
              <Logo />
              <button
                type="button"
                onClick={() => setMobileOpen(false)}
                className="mr-3 rounded-md p-1.5 text-slate-400 transition-colors hover:bg-surface-2 hover:text-slate-50"
                aria-label="Close navigation"
              >
                <X className="size-5" />
              </button>
            </div>
            <NavLinks onNavigate={() => setMobileOpen(false)} />
          </aside>
        </div>
      )}
    </>
  );
}
