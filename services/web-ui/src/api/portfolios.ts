/**
 * Portfolio endpoints: /api/tenants/:tenantId/portfolios
 * Dashboard endpoint: /api/tenants/:tenantId/dashboard/:portfolioId
 */

import { apiDelete, apiGet, apiPatch, apiPost } from "./client";
import type {
  PortfolioCreate,
  PortfolioDashboard,
  PortfolioResponse,
  PortfolioUpdate,
} from "../types";

export function getPortfolios(tenantId: string): Promise<PortfolioResponse[]> {
  return apiGet<PortfolioResponse[]>(`/tenants/${tenantId}/portfolios`);
}

export function createPortfolio(
  tenantId: string,
  data: PortfolioCreate,
): Promise<PortfolioResponse> {
  return apiPost<PortfolioResponse>(`/tenants/${tenantId}/portfolios`, data);
}

export function getPortfolio(
  tenantId: string,
  portfolioId: string,
): Promise<PortfolioResponse> {
  return apiGet<PortfolioResponse>(
    `/tenants/${tenantId}/portfolios/${portfolioId}`,
  );
}

export function updatePortfolio(
  tenantId: string,
  portfolioId: string,
  data: PortfolioUpdate,
): Promise<PortfolioResponse> {
  return apiPatch<PortfolioResponse>(
    `/tenants/${tenantId}/portfolios/${portfolioId}`,
    data,
  );
}

export function deletePortfolio(
  tenantId: string,
  portfolioId: string,
): Promise<void> {
  return apiDelete(`/tenants/${tenantId}/portfolios/${portfolioId}`);
}

export function getPortfolioDashboard(
  tenantId: string,
  portfolioId: string,
): Promise<PortfolioDashboard> {
  return apiGet<PortfolioDashboard>(
    `/tenants/${tenantId}/dashboard/${portfolioId}`,
  );
}
