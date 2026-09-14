import { useState, type FormEvent } from "react";
import { useNavigate } from "react-router-dom";
import {
  Briefcase,
  Brain,
  ChartLine,
  ShieldAlert,
  ShieldCheck,
} from "lucide-react";
import { bootstrap as apiBootstrap, login as apiLogin } from "../api/auth";
import { useAuthStore } from "../stores/auth";
import { Button } from "../components/ui/Button";
import { Input } from "../components/ui/Input";

export default function LoginPage() {
  const navigate = useNavigate();
  const storeLogin = useAuthStore((state) => state.login);

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [bootstrapMode, setBootstrapMode] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);
    setLoading(true);

    try {
      // Bootstrap creates the first platform admin and only succeeds on a
      // fresh platform (no users); it returns a token like /auth/login.
      const response = bootstrapMode
        ? await apiBootstrap({ email, password })
        : await apiLogin({ email, password });
      storeLogin(response.access_token, email);
      navigate("/dashboard", { replace: true });
    } catch (err) {
      setError(err instanceof Error ? err.message : "Sign in failed");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="flex min-h-screen bg-slate-50">
      {/* Brand hero — lg and up */}
      <div className="relative hidden w-1/2 flex-col justify-between overflow-hidden bg-gradient-to-br from-brand-700 via-brand-600 to-accent-600 p-10 text-white lg:flex xl:p-14">
        <div className="flex items-center gap-2 text-lg font-semibold">
          <ShieldCheck className="h-7 w-7" />
          Aegis Trader
        </div>
        <div className="max-w-md">
          <h1 className="text-3xl font-semibold leading-tight xl:text-[2.6rem]">
            Intelligent trading, disciplined risk.
          </h1>
          <p className="mt-4 text-sm leading-relaxed text-white/80">
            AI-powered portfolio management with real-time risk controls,
            strategy backtesting, and multi-broker execution.
          </p>
          <ul className="mt-8 space-y-4">
            <li className="flex gap-3">
              <span className="mt-0.5 flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-white/15">
                <Briefcase className="h-5 w-5" />
              </span>
              <div>
                <p className="text-sm font-medium">Portfolio Management</p>
                <p className="text-xs leading-relaxed text-white/70">
                  Multi-portfolio support with live and paper trading modes
                </p>
              </div>
            </li>
            <li className="flex gap-3">
              <span className="mt-0.5 flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-white/15">
                <ChartLine className="h-5 w-5" />
              </span>
              <div>
                <p className="text-sm font-medium">Strategy Engine</p>
                <p className="text-xs leading-relaxed text-white/70">
                  Backtest and deploy strategies with AI-driven allocation
                </p>
              </div>
            </li>
            <li className="flex gap-3">
              <span className="mt-0.5 flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-white/15">
                <ShieldAlert className="h-5 w-5" />
              </span>
              <div>
                <p className="text-sm font-medium">Risk Controls</p>
                <p className="text-xs leading-relaxed text-white/70">
                  Real-time risk policies, kill switches, and audit logging
                </p>
              </div>
            </li>
            <li className="flex gap-3">
              <span className="mt-0.5 flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-white/15">
                <Brain className="h-5 w-5" />
              </span>
              <div>
                <p className="text-sm font-medium">Market Intelligence</p>
                <p className="text-xs leading-relaxed text-white/70">
                  AI decisions, regime detection, and news sentiment analysis
                </p>
              </div>
            </li>
          </ul>
        </div>
        <p className="text-xs text-white/60">Algorithmic trading platform</p>
      </div>

      {/* Form column */}
      <div className="flex w-full flex-col lg:w-1/2">
        <div className="flex items-center gap-2 p-6 text-lg font-semibold text-brand-700 lg:hidden">
          <ShieldCheck className="h-6 w-6" />
          Aegis Trader
        </div>
        <div className="flex flex-1 items-center justify-center px-6 pb-12 sm:px-10">
          <div className="w-full max-w-sm">
            <div className="mb-6 flex flex-col items-center">
              <ShieldCheck className="size-10 text-brand-700" />
              <h2 className="mt-3 text-2xl font-semibold text-slate-900">
                {bootstrapMode
                  ? "Bootstrap Aegis Trader"
                  : "Sign in to Aegis Trader"}
              </h2>
              {bootstrapMode && (
                <p className="mt-1 text-center text-sm text-slate-500">
                  Creates the first platform admin. Only available on a fresh
                  platform.
                </p>
              )}
            </div>

            <form onSubmit={handleSubmit} className="space-y-4">
              <Input
                label="Email"
                type="email"
                autoComplete="email"
                required
                value={email}
                onChange={(event) => setEmail(event.target.value)}
                placeholder="you@example.com"
              />
              <Input
                label="Password"
                type="password"
                autoComplete={
                  bootstrapMode ? "new-password" : "current-password"
                }
                required
                value={password}
                onChange={(event) => setPassword(event.target.value)}
                placeholder="••••••••"
              />

              {error && (
                <p className="rounded-md border border-loss/30 bg-loss/10 px-3 py-2 text-sm text-loss">
                  {error}
                </p>
              )}

              <Button type="submit" loading={loading} className="w-full">
                {bootstrapMode ? "Bootstrap platform" : "Sign in"}
              </Button>
            </form>

            <button
              type="button"
              onClick={() => {
                setBootstrapMode((prev) => !prev);
                setError(null);
              }}
              className="mt-4 w-full text-center text-xs text-slate-500 transition-colors hover:text-brand-800"
            >
              {bootstrapMode
                ? "Already have an account? Sign in"
                : "First time? Bootstrap the platform"}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
