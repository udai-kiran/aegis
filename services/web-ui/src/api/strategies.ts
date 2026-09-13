/**
 * Strategy endpoints: /api/tenants/:tenantId/strategies
 * Strategy config endpoints: /api/tenants/:tenantId/strategy-configs
 * Strategy health endpoints: /api/tenants/:tenantId/strategy-health
 */

import { apiDelete, apiGet, apiPatch, apiPost } from "./client";
import type {
  DegradationCheckRequest,
  DegradationCheckResponse,
  HealthEvaluateRequest,
  StrategyConfigCreate,
  StrategyConfigResponse,
  StrategyConfigUpdate,
  StrategyCreate,
  StrategyHealthResponse,
  StrategyResponse,
  StrategyUpdate,
} from "../types";

// --- Strategies ---

export function getStrategies(tenantId: string): Promise<StrategyResponse[]> {
  return apiGet<StrategyResponse[]>(`/tenants/${tenantId}/strategies`);
}

export function createStrategy(
  tenantId: string,
  data: StrategyCreate,
): Promise<StrategyResponse> {
  return apiPost<StrategyResponse>(`/tenants/${tenantId}/strategies`, data);
}

export function getStrategy(
  tenantId: string,
  strategyId: string,
): Promise<StrategyResponse> {
  return apiGet<StrategyResponse>(
    `/tenants/${tenantId}/strategies/${strategyId}`,
  );
}

export function updateStrategy(
  tenantId: string,
  strategyId: string,
  data: StrategyUpdate,
): Promise<StrategyResponse> {
  return apiPatch<StrategyResponse>(
    `/tenants/${tenantId}/strategies/${strategyId}`,
    data,
  );
}

// --- Strategy configs ---

export function getStrategyConfigs(
  tenantId: string,
): Promise<StrategyConfigResponse[]> {
  return apiGet<StrategyConfigResponse[]>(
    `/tenants/${tenantId}/strategy-configs`,
  );
}

export function createStrategyConfig(
  tenantId: string,
  data: StrategyConfigCreate,
): Promise<StrategyConfigResponse> {
  return apiPost<StrategyConfigResponse>(
    `/tenants/${tenantId}/strategy-configs`,
    data,
  );
}

export function getStrategyConfig(
  tenantId: string,
  configId: string,
): Promise<StrategyConfigResponse> {
  return apiGet<StrategyConfigResponse>(
    `/tenants/${tenantId}/strategy-configs/${configId}`,
  );
}

export function updateStrategyConfig(
  tenantId: string,
  configId: string,
  data: StrategyConfigUpdate,
): Promise<StrategyConfigResponse> {
  return apiPatch<StrategyConfigResponse>(
    `/tenants/${tenantId}/strategy-configs/${configId}`,
    data,
  );
}

export function deleteStrategyConfig(
  tenantId: string,
  configId: string,
): Promise<void> {
  return apiDelete(`/tenants/${tenantId}/strategy-configs/${configId}`);
}

// --- Strategy health ---

export function evaluateStrategyHealth(
  tenantId: string,
  data: HealthEvaluateRequest,
): Promise<StrategyHealthResponse> {
  return apiPost<StrategyHealthResponse>(
    `/tenants/${tenantId}/strategy-health/evaluate`,
    data,
  );
}

export function getStrategyHealthScores(
  tenantId: string,
): Promise<StrategyHealthResponse[]> {
  return apiGet<StrategyHealthResponse[]>(
    `/tenants/${tenantId}/strategy-health`,
  );
}

export function getStrategyHealth(
  tenantId: string,
  healthId: string,
): Promise<StrategyHealthResponse> {
  return apiGet<StrategyHealthResponse>(
    `/tenants/${tenantId}/strategy-health/${healthId}`,
  );
}

export function checkDegradation(
  tenantId: string,
  data: DegradationCheckRequest,
): Promise<DegradationCheckResponse> {
  return apiPost<DegradationCheckResponse>(
    `/tenants/${tenantId}/strategy-health/degradation-check`,
    data,
  );
}
