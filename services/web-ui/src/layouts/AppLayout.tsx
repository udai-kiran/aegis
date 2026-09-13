import { Navigate, Outlet } from "react-router-dom";
import { useAuthStore } from "../stores/auth";
import Sidebar from "./Sidebar";

export default function AppLayout() {
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);

  if (!isAuthenticated()) {
    return <Navigate to="/login" replace />;
  }

  return (
    <div className="min-h-screen bg-surface-0 text-slate-50">
      <Sidebar />
      <main className="min-h-screen pt-14 md:pl-64 md:pt-0">
        <div className="p-4 md:p-8">
          <Outlet />
        </div>
      </main>
    </div>
  );
}
