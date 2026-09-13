/**
 * Auth endpoints: POST /api/auth/login, POST /api/auth/bootstrap
 */

import { apiPost } from "./client";
import type { BootstrapRequest, LoginRequest, TokenResponse } from "../types";

export function login(data: LoginRequest): Promise<TokenResponse> {
  return apiPost<TokenResponse>("/auth/login", data);
}

export function bootstrap(data: BootstrapRequest): Promise<TokenResponse> {
  return apiPost<TokenResponse>("/auth/bootstrap", data);
}
