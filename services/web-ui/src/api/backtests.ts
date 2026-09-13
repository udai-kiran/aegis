/**
 * Backtest endpoints: /api/tenants/:tenantId/backtests
 */

import { apiGet, apiPost, qs } from "./client";
import type { BacktestCreate, BacktestResponse } from "../types";

export interface ListBacktestsParams {
  portfolioId?: string;
  status?: string;
}

export function createBacktest(
  tenantId: string,
  data: BacktestCreate,
): Promise<BacktestResponse> {
  return apiPost<BacktestResponse>(`/tenants/${tenantId}/backtests`, data);
}

export function getBacktests(
  tenantId: string,
  params: ListBacktestsParams = {},
): Promise<BacktestResponse[]> {
  return apiGet<BacktestResponse[]>(
    `/tenants/${tenantId}/backtests${qs({
      portfolio_id: params.portfolioId,
      status: params.status,
    })}`,
  );
}

export function getBacktest(
  tenantId: string,
  backtestId: string,
): Promise<BacktestResponse> {
  return apiGet<BacktestResponse>(
    `/tenants/${tenantId}/backtests/${backtestId}`,
  );
}
