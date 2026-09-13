/**
 * Risk policy endpoints: /api/tenants/:tenantId/risk-policies
 * Kill switch endpoints: /api/tenants/:tenantId/kill-switch
 */

import { apiDelete, apiGet, apiPatch, apiPost } from "./client";
import type {
  KillSwitchAction,
  KillSwitchStatus,
  RiskPolicyCreate,
  RiskPolicyResponse,
  RiskPolicyUpdate,
} from "../types";

// --- Risk policies ---

export function getRiskPolicies(
  tenantId: string,
): Promise<RiskPolicyResponse[]> {
  return apiGet<RiskPolicyResponse[]>(`/tenants/${tenantId}/risk-policies`);
}

export function createRiskPolicy(
  tenantId: string,
  data: RiskPolicyCreate,
): Promise<RiskPolicyResponse> {
  return apiPost<RiskPolicyResponse>(
    `/tenants/${tenantId}/risk-policies`,
    data,
  );
}

export function getRiskPolicy(
  tenantId: string,
  policyId: string,
): Promise<RiskPolicyResponse> {
  return apiGet<RiskPolicyResponse>(
    `/tenants/${tenantId}/risk-policies/${policyId}`,
  );
}

export function updateRiskPolicy(
  tenantId: string,
  policyId: string,
  data: RiskPolicyUpdate,
): Promise<RiskPolicyResponse> {
  return apiPatch<RiskPolicyResponse>(
    `/tenants/${tenantId}/risk-policies/${policyId}`,
    data,
  );
}

export function deleteRiskPolicy(
  tenantId: string,
  policyId: string,
): Promise<void> {
  return apiDelete(`/tenants/${tenantId}/risk-policies/${policyId}`);
}

// --- Kill switch ---

export interface KillSwitchActionResult {
  readonly status: string;
  readonly scope: string;
  readonly action: string;
  readonly target_id: string;
}

export interface EmergencyHaltResult {
  readonly status: string;
  readonly scope: string;
}

export function getKillSwitchStatus(
  tenantId: string,
): Promise<KillSwitchStatus> {
  return apiGet<KillSwitchStatus>(`/tenants/${tenantId}/kill-switch`);
}

export function applyKillSwitch(
  tenantId: string,
  data: KillSwitchAction,
): Promise<KillSwitchActionResult> {
  return apiPost<KillSwitchActionResult>(
    `/tenants/${tenantId}/kill-switch`,
    data,
  );
}

export function emergencyHalt(tenantId: string): Promise<EmergencyHaltResult> {
  return apiPost<EmergencyHaltResult>(
    `/tenants/${tenantId}/kill-switch/emergency-halt`,
  );
}
