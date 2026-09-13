/**
 * AI / intelligence endpoints:
 * - Allocation & decisions: /api/tenants/:tenantId/ai/allocate, /ai/decisions
 * - Shadow results & rewards: /ai/shadow-results, /ai/reward
 * - LLM supervisor: /ai/supervisor/recommend, /ai/supervisor/actions
 * - Counterfactual: /ai/counterfactual/evaluate
 * - Market regimes: /api/market-regimes
 * - Degradation detection lives in ./strategies (strategy-health router).
 */

import { apiGet, apiPost, qs } from "./client";
import type {
  AIDecisionResponse,
  AllocationRequest,
  CounterfactualRequest,
  CounterfactualResponse,
  MarketRegimeResponse,
  RegimeComputeRequest,
  RewardRequest,
  RewardResponse,
  ShadowResultCreate,
  ShadowResultResponse,
  SupervisorActionResponse,
  SupervisorRecommendRequest,
} from "../types";

// --- AI allocation & decisions ---

export function allocate(
  tenantId: string,
  data: AllocationRequest,
): Promise<AIDecisionResponse> {
  return apiPost<AIDecisionResponse>(`/tenants/${tenantId}/ai/allocate`, data);
}

export function getAIDecisions(
  tenantId: string,
): Promise<AIDecisionResponse[]> {
  return apiGet<AIDecisionResponse[]>(`/tenants/${tenantId}/ai/decisions`);
}

export function getAIDecision(
  tenantId: string,
  decisionId: string,
): Promise<AIDecisionResponse> {
  return apiGet<AIDecisionResponse>(
    `/tenants/${tenantId}/ai/decisions/${decisionId}`,
  );
}

// --- Shadow results ---

export function createShadowResult(
  tenantId: string,
  data: ShadowResultCreate,
): Promise<ShadowResultResponse> {
  return apiPost<ShadowResultResponse>(
    `/tenants/${tenantId}/ai/shadow-results`,
    data,
  );
}

export function getShadowResults(
  tenantId: string,
): Promise<ShadowResultResponse[]> {
  return apiGet<ShadowResultResponse[]>(
    `/tenants/${tenantId}/ai/shadow-results`,
  );
}

// --- Rewards / adaptive allocation ---

export function submitReward(
  tenantId: string,
  data: RewardRequest,
): Promise<RewardResponse> {
  return apiPost<RewardResponse>(`/tenants/${tenantId}/ai/reward`, data);
}

// --- LLM supervisor ---

export function recommendSupervisorActions(
  tenantId: string,
  data: SupervisorRecommendRequest,
): Promise<SupervisorActionResponse[]> {
  return apiPost<SupervisorActionResponse[]>(
    `/tenants/${tenantId}/ai/supervisor/recommend`,
    data,
  );
}

export function getSupervisorActions(
  tenantId: string,
): Promise<SupervisorActionResponse[]> {
  return apiGet<SupervisorActionResponse[]>(
    `/tenants/${tenantId}/ai/supervisor/actions`,
  );
}

export function getSupervisorAction(
  tenantId: string,
  actionId: string,
): Promise<SupervisorActionResponse> {
  return apiGet<SupervisorActionResponse>(
    `/tenants/${tenantId}/ai/supervisor/actions/${actionId}`,
  );
}

// --- Counterfactual ---

export function evaluateCounterfactual(
  tenantId: string,
  data: CounterfactualRequest,
): Promise<CounterfactualResponse> {
  return apiPost<CounterfactualResponse>(
    `/tenants/${tenantId}/ai/counterfactual/evaluate`,
    data,
  );
}

// --- Market regimes ---

export function computeMarketRegime(
  data: RegimeComputeRequest,
): Promise<MarketRegimeResponse> {
  return apiPost<MarketRegimeResponse>("/market-regimes/compute", data);
}

export interface ListMarketRegimesParams {
  symbol?: string;
  limit?: number;
}

export function getMarketRegimes(
  params: ListMarketRegimesParams = {},
): Promise<MarketRegimeResponse[]> {
  return apiGet<MarketRegimeResponse[]>(
    `/market-regimes${qs({ symbol: params.symbol, limit: params.limit })}`,
  );
}

export function getMarketRegime(
  regimeId: string,
): Promise<MarketRegimeResponse> {
  return apiGet<MarketRegimeResponse>(`/market-regimes/${regimeId}`);
}
