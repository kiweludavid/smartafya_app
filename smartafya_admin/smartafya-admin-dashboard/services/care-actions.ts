import { api } from '@/services/api'

export type PatientTransferRequestOut = {
  id: string
  session_id: string
  from_doctor_id: string
  to_doctor_id: string
  reason: string
  status: string
  created_at: string
  updated_at: string
}

export type AdminSessionManagementSummaryOut = {
  pending_transfer_requests: PatientTransferRequestOut[]
  pending_unavailability_impacts: {
    impact_id: string
    session_id: string
    client_id: string
    doctor_id: string
    status: string
    block_starts_at: string
    block_ends_at: string
    session_scheduled_at: string | null
  }[]
}

export async function getAdminSessionManagementSummary(): Promise<AdminSessionManagementSummaryOut> {
  const res = await api.get<AdminSessionManagementSummaryOut>('/api/v1/care-actions/admin/session-management-summary')
  return res.data
}

