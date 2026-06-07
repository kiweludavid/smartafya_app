import { api } from '@/services/api'
import type { UserOut } from '@/lib/api'

export type ClientApi = {
  id?: string
  name?: string
  full_name?: string
  email?: string
  phone?: string
  [key: string]: unknown
}

export async function listClients() {
  const res = await api.get<UserOut[]>('/api/v1/users/?skip=0&limit=1000')
  const clients = res.data.filter((u) => u.role === 'client')
  return clients as ClientApi[]
}
