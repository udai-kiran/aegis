/**
 * Zustand auth store with localStorage persistence.
 *
 * On login, the JWT payload (middle segment) is base64-decoded to extract
 * `sub` (user id), `tenant_id`, and `role` as issued by the backend
 * (`services/api-gateway/app/auth.py`).
 */

import { create } from "zustand";
import { persist } from "zustand/middleware";

interface JwtPayload {
  sub?: string;
  tenant_id?: string | null;
  role?: string;
}

function decodeJwtPayload(token: string): JwtPayload {
  const segment = token.split(".")[1];
  if (!segment) {
    return {};
  }
  // Convert base64url to base64
  const base64 = segment.replace(/-/g, "+").replace(/_/g, "/");
  const json = atob(base64);
  return JSON.parse(json) as JwtPayload;
}

export interface AuthState {
  token: string | null;
  tenantId: string | null;
  userId: string | null;
  role: string | null;
  email: string | null;
  login: (token: string, email?: string) => void;
  logout: () => void;
  isAuthenticated: () => boolean;
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set, get) => ({
      token: null,
      tenantId: null,
      userId: null,
      role: null,
      email: null,

      login: (token: string, email?: string) => {
        const payload = decodeJwtPayload(token);
        set({
          token,
          userId: payload.sub ?? null,
          tenantId: payload.tenant_id ?? null,
          role: payload.role ?? null,
          email: email ?? null,
        });
      },

      logout: () => {
        set({
          token: null,
          tenantId: null,
          userId: null,
          role: null,
          email: null,
        });
        // Avoid redirect loops when a 401 is received while already on /login
        if (window.location.pathname !== "/login") {
          window.location.assign("/login");
        }
      },

      isAuthenticated: () => get().token !== null,
    }),
    {
      name: "aegis-auth",
    },
  ),
);
