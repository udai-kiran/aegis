import { Navigate, Outlet } from "react-router-dom";
import { useAuthStore } from "../stores/auth";
import Sidebar from "./Sidebar";

export default function AppLayout() {
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);
  const email = useAuthStore((state) => state.email);
  const logout = useAuthStore((state) => state.logout);

  if (!isAuthenticated()) {
    return <Navigate to="/login" replace />;
  }

  return (
    <div className="flex h-screen bg-slate-100">
      <a
        href="#main-content"
        className="sr-only focus:not-sr-only focus:absolute focus:left-2 focus:top-2 focus:z-50 focus:rounded-md focus:bg-slate-900 focus:px-3 focus:py-2 focus:text-sm focus:text-white"
      >
        Skip to content
      </a>
      <Sidebar />
      <div className="flex flex-1 flex-col pt-14 md:pt-0">
        <header className="flex h-14 items-center justify-between border-b border-slate-200 bg-white px-4 sm:px-6">
          <div
            className="flex items-center gap-2 rounded-lg border border-slate-200 px-3 py-1.5 text-sm text-slate-400"
            aria-hidden="true"
          >
            Search…
          </div>
          <div className="flex items-center gap-3 sm:gap-4">
            <span className="hidden text-sm text-slate-600 sm:inline">
              {email}
            </span>
            <button
              type="button"
              onClick={logout}
              className="rounded-lg border border-slate-300 px-3 py-1.5 text-sm text-slate-600 transition hover:bg-slate-50"
            >
              Log out
            </button>
          </div>
        </header>
        <main id="main-content" className="flex-1 overflow-y-auto p-4 sm:p-6">
          <div className="mx-auto h-full w-full max-w-5xl">
            <Outlet />
          </div>
        </main>
      </div>
    </div>
  );
}
