import { api } from '@/services/api'
import type { FeedbackOut } from '@/lib/api'

export type FeedbackApi = {
  id?: string
  session_id?: string
  consultation_id?: string
  rating?: number
  comment?: string
  created_at?: string
  [key: string]: unknown
}

export async function listFeedback() {
  const res = await api.get<FeedbackOut[]>('/api/v1/feedback/')
  return res.data as FeedbackApi[]
}
