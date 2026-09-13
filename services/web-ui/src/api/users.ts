/**
 * User endpoints: /api/tenants/:tenantId/users
 */

import { apiGet, apiPatch, apiPost } from "./client";
import type { UserCreate, UserResponse, UserUpdate } from "../types";

export function getUsers(tenantId: string): Promise<UserResponse[]> {
  return apiGet<UserResponse[]>(`/tenants/${tenantId}/users`);
}

export function createUser(
  tenantId: string,
  data: UserCreate,
): Promise<UserResponse> {
  return apiPost<UserResponse>(`/tenants/${tenantId}/users`, data);
}

export function updateUser(
  tenantId: string,
  userId: string,
  data: UserUpdate,
): Promise<UserResponse> {
  return apiPatch<UserResponse>(`/tenants/${tenantId}/users/${userId}`, data);
}
