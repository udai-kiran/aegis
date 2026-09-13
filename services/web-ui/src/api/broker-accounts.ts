/**
 * Broker account endpoints: /api/tenants/:tenantId/broker-accounts
 * Execution endpoints: /api/tenants/:tenantId/execution
 */

import { apiDelete, apiGet, apiPatch, apiPost, qs } from "./client";
import type {
  BrokerAccountCreate,
  BrokerAccountResponse,
  BrokerAccountUpdate,
  ExecutionRequest,
  OrderResponse,
  ReconciliationResult,
} from "../types";

// --- Broker accounts ---

export function getBrokerAccounts(
  tenantId: string,
): Promise<BrokerAccountResponse[]> {
  return apiGet<BrokerAccountResponse[]>(
    `/tenants/${tenantId}/broker-accounts`,
  );
}

export function createBrokerAccount(
  tenantId: string,
  data: BrokerAccountCreate,
): Promise<BrokerAccountResponse> {
  return apiPost<BrokerAccountResponse>(
    `/tenants/${tenantId}/broker-accounts`,
    data,
  );
}

export function getBrokerAccount(
  tenantId: string,
  accountId: string,
): Promise<BrokerAccountResponse> {
  return apiGet<BrokerAccountResponse>(
    `/tenants/${tenantId}/broker-accounts/${accountId}`,
  );
}

export function updateBrokerAccount(
  tenantId: string,
  accountId: string,
  data: BrokerAccountUpdate,
): Promise<BrokerAccountResponse> {
  return apiPatch<BrokerAccountResponse>(
    `/tenants/${tenantId}/broker-accounts/${accountId}`,
    data,
  );
}

export function deleteBrokerAccount(
  tenantId: string,
  accountId: string,
): Promise<void> {
  return apiDelete(`/tenants/${tenantId}/broker-accounts/${accountId}`);
}

// --- Execution ---

export function submitExecutionOrder(
  tenantId: string,
  data: ExecutionRequest,
): Promise<OrderResponse> {
  return apiPost<OrderResponse>(`/tenants/${tenantId}/execution/orders`, data);
}

export interface ListExecutionOrdersParams {
  brokerAccountId?: string;
  status?: string;
}

export function getExecutionOrders(
  tenantId: string,
  params: ListExecutionOrdersParams = {},
): Promise<OrderResponse[]> {
  return apiGet<OrderResponse[]>(
    `/tenants/${tenantId}/execution/orders${qs({
      broker_account_id: params.brokerAccountId,
      status: params.status,
    })}`,
  );
}

export function reconcileBrokerAccount(
  tenantId: string,
  accountId: string,
): Promise<ReconciliationResult> {
  return apiPost<ReconciliationResult>(
    `/tenants/${tenantId}/execution/reconcile/${accountId}`,
  );
}
