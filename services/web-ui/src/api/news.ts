/**
 * News endpoints: /api/tenants/:tenantId/news
 */

import { apiGet, apiPost, qs } from "./client";
import type { NewsItemCreate, NewsItemResponse } from "../types";

export interface ListNewsParams {
  symbol?: string;
  limit?: number;
}

export function createNewsItem(
  tenantId: string,
  data: NewsItemCreate,
): Promise<NewsItemResponse> {
  return apiPost<NewsItemResponse>(`/tenants/${tenantId}/news`, data);
}

export function getNewsItems(
  tenantId: string,
  params: ListNewsParams = {},
): Promise<NewsItemResponse[]> {
  return apiGet<NewsItemResponse[]>(
    `/tenants/${tenantId}/news${qs({ symbol: params.symbol, limit: params.limit })}`,
  );
}

export function getNewsItem(
  tenantId: string,
  newsId: string,
): Promise<NewsItemResponse> {
  return apiGet<NewsItemResponse>(`/tenants/${tenantId}/news/${newsId}`);
}
