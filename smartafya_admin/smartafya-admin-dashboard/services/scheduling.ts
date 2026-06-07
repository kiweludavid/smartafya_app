import { api } from '@/services/api'
import type { SessionOut } from '@/lib/api'
import axios from 'axios'

export type ScheduleSessionPayload = {
  consultation_id: string
  client_id?: string
  specialist_id?: string
  specialist_name?: string
  date?: string
  time?: string
  duration_minutes?: number
  meeting_platform?: 'zoom' | 'google-meet'
  meeting_link?: string
  instructions?: string
}

function toScheduledIso(date: string, time: string) {
  const normalized = time.length === 5 ? `${time}:00` : time
  const d = new Date(`${date}T${normalized}`)
  if (Number.isNaN(d.getTime())) throw new Error('Invalid date or time')
  return d.toISOString()
}

/**
 * Confirm a session schedule on the API.
 * - When specialist + date + time are provided, it assigns the doctor and persists the
 *   scheduled time and meeting link in one call.
 * - When only `instructions` are provided, it stores them on the session as notes
 *   (kept as a fallback for the older single-step flow).
 */
export async function scheduleSession(payload: ScheduleSessionPayload): Promise<SessionOut | null> {
  const { consultation_id, specialist_id, date, time, meeting_link, instructions } = payload

  if (instructions?.trim() && !specialist_id && !date) {
    const res = await api.patch<SessionOut>(`/api/v1/sessions/${consultation_id}`, { notes: instructions.trim() })
    return res.data
  }

  if (!specialist_id || !date || !time) {
    throw new Error('Missing doctor, date, or time')
  }

  const scheduled_at = toScheduledIso(date, time)
  const res = await api.post<SessionOut>(`/api/v1/sessions/${consultation_id}/assign`, {
    doctor_id: specialist_id,
    scheduled_at,
    meeting_link: meeting_link ?? null,
  })
  return res.data
}

/** Send session instructions to the client via the persistent admin–client chat thread. */
export async function sendSessionInstructions(args: { consultation_id: string; body: string }) {
  const trimmed = args.body.trim()
  if (!trimmed) throw new Error('Empty instructions')

  try {
    const conversationsRes = await api.get<
      { id: string; session_id: string | null; is_expired: boolean }[]
    >('/api/v1/chat/conversations')
    const conversation = conversationsRes.data.find(
      (c) => String(c.session_id || '') === String(args.consultation_id)
    )
    if (!conversation) {
      throw new Error('No chat conversation found for this session')
    }
    if (conversation.is_expired) {
      throw new Error('Chat for this session is expired')
    }
    await api.post(`/api/v1/chat/conversations/${conversation.id}/messages`, { body: trimmed })
  } catch (err: unknown) {
    if (axios.isAxiosError(err)) {
      const status = err.response?.status
      const data = err.response?.data as any
      const detail =
        typeof data?.detail === 'string'
          ? data.detail
          : typeof data?.message === 'string'
            ? data.message
            : undefined
      const suffix = [status ? `HTTP ${status}` : null, detail || null].filter(Boolean).join(' • ')
      throw new Error(suffix ? `Failed to send instructions (${suffix})` : 'Failed to send instructions')
    }
    throw err
  }
}
