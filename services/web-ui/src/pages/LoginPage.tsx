import { useState, type FormEvent } from "react";
import { useNavigate } from "react-router-dom";
import { ShieldCheck } from "lucide-react";
import { bootstrap as apiBootstrap, login as apiLogin } from "../api/auth";
import { useAuthStore } from "../stores/auth";
import { Button } from "../components/ui/Button";
import { Card } from "../components/ui/Card";
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
    <div className="flex min-h-screen items-center justify-center bg-surface-0 px-4">
      <div className="w-full max-w-sm">
        <div className="mb-6 flex flex-col items-center">
          <ShieldCheck className="size-10 text-brand-400" />
          <h1 className="mt-3 text-xl font-semibold text-slate-50">
            {bootstrapMode
              ? "Bootstrap Aegis Trader"
              : "Sign in to Aegis Trader"}
          </h1>
          {bootstrapMode && (
            <p className="mt-1 text-center text-xs text-slate-400">
              Creates the first platform admin. Only available on a fresh
              platform.
            </p>
          )}
        </div>

        <Card>
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
              autoComplete={bootstrapMode ? "new-password" : "current-password"}
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
        </Card>

        <button
          type="button"
          onClick={() => {
            setBootstrapMode((prev) => !prev);
            setError(null);
          }}
          className="mt-4 w-full text-center text-xs text-slate-400 transition-colors hover:text-brand-400"
        >
          {bootstrapMode
            ? "Already have an account? Sign in"
            : "First time? Bootstrap the platform"}
        </button>
      </div>
    </div>
  );
}
