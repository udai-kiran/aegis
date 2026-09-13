/**
 * Tenant endpoints: /api/tenants
 */

import { apiGet, apiPatch, apiPost } from "./client";
import type { TenantCreate, TenantResponse, TenantUpdate } from "../types";

export function getTenants(): Promise<TenantResponse[]> {
  return apiGet<TenantResponse[]>("/tenants");
}

export function createTenant(data: TenantCreate): Promise<TenantResponse> {
  return apiPost<TenantResponse>("/tenants", data);
}

export function getTenant(tenantId: string): Promise<TenantResponse> {
  return apiGet<TenantResponse>(`/tenants/${tenantId}`);
}

export function updateTenant(
  tenantId: string,
  data: TenantUpdate,
): Promise<TenantResponse> {
  return apiPatch<TenantResponse>(`/tenants/${tenantId}`, data);
}
