import { Link } from "react-router-dom";

export default function NotFoundPage() {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-slate-50 px-4 text-center">
      <p className="text-6xl font-bold text-brand-600">404</p>
      <h1 className="mt-4 text-xl font-semibold text-slate-800">
        Page not found
      </h1>
      <p className="mt-2 text-sm text-slate-500">
        The page you are looking for does not exist.
      </p>
      <Link
        to="/dashboard"
        className="mt-6 rounded-md bg-brand-600 px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-brand-700"
      >
        Go to Dashboard
      </Link>
    </div>
  );
}
