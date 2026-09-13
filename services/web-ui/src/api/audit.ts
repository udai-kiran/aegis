/**
 * Audit endpoints: /api/tenants/:tenantId/audit
 */

import { apiGet, qs } from "./client";
import type { AuditEventResponse } from "../types";

export interface ListAuditEventsParams {
  limit?: number;
  offset?: number;
}

export function getAuditEvents(
  tenantId: string,
  params: ListAuditEventsParams = {},
): Promise<AuditEventResponse[]> {
  return apiGet<AuditEventResponse[]>(
    `/tenants/${tenantId}/audit${qs({ limit: params.limit, offset: params.offset })}`,
  );
}
