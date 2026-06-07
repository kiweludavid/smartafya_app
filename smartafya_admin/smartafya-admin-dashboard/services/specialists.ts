import { api } from '@/services/api'
import type { SpecialistTypeApi, UserOut } from '@/lib/api'

export type SpecialistApi = {
  id?: string
  name?: string
  full_name?: string
  email?: string
  phone?: string
  type?: string
  specialist_type?: string
  is_available?: boolean
  availability?: unknown
}

export type ListSpecialistsOptions = {
  /** Filter to a single specialist type. Maps directly to the API enum. */
  specialistType?: SpecialistTypeApi
  /** Only include specialists currently marked available. */
  availableOnly?: boolean
}

export async function listSpecialists(opts: ListSpecialistsOptions = {}) {
  const params = new URLSearchParams()
  if (opts.specialistType) params.set('specialist_type', opts.specialistType)
  if (opts.availableOnly) params.set('available_only', 'true')
  const qs = params.toString()
  const res = await api.get<UserOut[]>(`/api/v1/users/doctors${qs ? `?${qs}` : ''}`)
  return res.data as SpecialistApi[]
}
