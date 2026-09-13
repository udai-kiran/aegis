import { Navigate, Route, Routes } from "react-router-dom";
import AppLayout from "./layouts/AppLayout";
import LoginPage from "./pages/LoginPage";
import DashboardPage from "./pages/DashboardPage";
import PortfoliosPage from "./pages/PortfoliosPage";
import PortfolioDetailPage from "./pages/PortfolioDetailPage";
import StrategiesPage from "./pages/StrategiesPage";
import BacktestsPage from "./pages/BacktestsPage";
import OrdersPage from "./pages/OrdersPage";
import RiskPage from "./pages/RiskPage";
import IntelligencePage from "./pages/IntelligencePage";
import SettingsPage from "./pages/SettingsPage";
import NotFoundPage from "./pages/NotFoundPage";

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route path="/" element={<Navigate to="/dashboard" replace />} />

      <Route element={<AppLayout />}>
        <Route path="/dashboard" element={<DashboardPage />} />
        <Route path="/portfolios" element={<PortfoliosPage />} />
        <Route
          path="/portfolios/:portfolioId"
          element={<PortfolioDetailPage />}
        />
        <Route path="/strategies" element={<StrategiesPage />} />
        <Route path="/backtests" element={<BacktestsPage />} />
        <Route path="/orders" element={<OrdersPage />} />
        <Route path="/risk" element={<RiskPage />} />
        <Route path="/intelligence" element={<IntelligencePage />} />
        <Route path="/settings" element={<SettingsPage />} />
      </Route>

      <Route path="*" element={<NotFoundPage />} />
    </Routes>
  );
}
