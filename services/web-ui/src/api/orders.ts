/**
 * Order endpoints: /api/tenants/:tenantId/orders
 * Paper trading endpoints: /api/tenants/:tenantId/paper-orders
 * Position endpoints: /api/tenants/:tenantId/portfolios/:portfolioId/positions
 */

import { apiGet, apiPost, qs } from "./client";
import type { OrderCreate, OrderResponse, PositionResponse } from "../types";

// --- Orders ---

export interface ListOrdersParams {
  portfolioId?: string;
  status?: string;
  symbol?: string;
}

export function getOrders(
  tenantId: string,
  params: ListOrdersParams = {},
): Promise<OrderResponse[]> {
  return apiGet<OrderResponse[]>(
    `/tenants/${tenantId}/orders${qs({
      portfolio_id: params.portfolioId,
      status: params.status,
      symbol: params.symbol,
    })}`,
  );
}

export function getOrder(
  tenantId: string,
  orderId: string,
): Promise<OrderResponse> {
  return apiGet<OrderResponse>(`/tenants/${tenantId}/orders/${orderId}`);
}

// --- Paper trading ---

export function submitPaperOrder(
  tenantId: string,
  data: OrderCreate,
): Promise<OrderResponse> {
  return apiPost<OrderResponse>(`/tenants/${tenantId}/paper-orders`, data);
}

// --- Positions ---

export function getPositions(
  tenantId: string,
  portfolioId: string,
  symbol?: string,
): Promise<PositionResponse[]> {
  return apiGet<PositionResponse[]>(
    `/tenants/${tenantId}/portfolios/${portfolioId}/positions${qs({ symbol })}`,
  );
}

export function getPosition(
  tenantId: string,
  portfolioId: string,
  positionId: string,
): Promise<PositionResponse> {
  return apiGet<PositionResponse>(
    `/tenants/${tenantId}/portfolios/${portfolioId}/positions/${positionId}`,
  );
}
