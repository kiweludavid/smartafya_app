export type ApiError = {
  status: number
  message: string
  details?: unknown
}

export type TokenResponse = {
  access_token: string
  token_type: string
}

export type UserRole = 'client' | 'doctor' | 'admin'
export type SpecialistTypeApi = 'psychologist' | 'psychiatrist' | 'therapist' | 'cleric' | 'influencer' | 'general'

export type UserOut = {
  id: string
  full_name: string
  email: string
  phone: string | null
  role: UserRole
  specialist_type: SpecialistTypeApi | null
  is_active: boolean
  is_verified: boolean
  is_available: boolean
  base_latitude: number | null
  base_longitude: number | null
  created_at: string
}

export type BookingOut = {
  id: string
  client_id: string
  preferred_specialist_id: string | null
  mental_health_description: string
  consent_given: boolean
  consent_timestamp: string | null
  session_type: 'audio' | 'video' | 'physical'
  duration_minutes: number
  preferred_dates: string
  status: 'pending' | 'confirmed' | 'cancelled'
  created_at: string
  physical_location_address?: string | null
  physical_location_lat?: number | null
  physical_location_lng?: number | null
  physical_venue?: 'home' | 'office' | null
  physical_notes?: string | null
  reschedule_request_dates?: string | null
  reschedule_request_note?: string | null
  reschedule_requested_at?: string | null
}

export type SessionOut = {
  id: string
  booking_id: string
  client_id: string
  doctor_id: string | null
  status: 'requested' | 'pending' | 'scheduled' | 'completed' | 'transferred' | 'cancelled'
  meeting_link: string | null
  scheduled_at: string | null
  notes: string | null
  check_in_at: string | null
  check_out_at: string | null
  created_at: string
  updated_at: string
}

export type PaymentStatusApi = 'pending' | 'proof_submitted' | 'paid' | 'refunded'
export type PaymentTypeApi = 'fixed' | 'negotiated'

export type PaymentOut = {
  id: string
  session_id: string
  amount: number | null
  status: PaymentStatusApi
  reference: string | null
  payment_type: PaymentTypeApi
  instructions_text: string | null
  proof_submitted_at: string | null
  proof_filename: string | null
  confirmed_at: string | null
  created_at: string
  updated_at: string
}

export type FeedbackOut = {
  id: string
  session_id: string
  client_id: string
  treatment_rating: number | null
  doctor_feedback: string | null
  app_rating: number | null
  app_feedback: string | null
  suggestions: string | null
  family_rating?: number | null
  family_comments?: string | null
  created_at: string
}

export type ConversationListItem = {
  id: string
  kind: 'session' | 'admin'
  title: string
  last_message_preview: string | null
  last_message_at: string | null
  expires_at: string | null
  is_expired: boolean
  session_id: string | null
}

const DEFAULT_BASE_URL = 'http://localhost:8000'
const DEFAULT_TIMEOUT_MS = 15000

export function getApiBaseUrl() {
  return (process.env.NEXT_PUBLIC_API_BASE_URL || DEFAULT_BASE_URL).replace(/\/$/, '')
}

function getApiTimeoutMs() {
  const raw = process.env.NEXT_PUBLIC_API_TIMEOUT_MS
  if (!raw) return DEFAULT_TIMEOUT_MS
  const n = Number(raw)
  return Number.isFinite(n) && n > 0 ? n : DEFAULT_TIMEOUT_MS
}

async function parseJsonSafe(res: Response) {
  try {
    return await res.json()
  } catch {
    return null
  }
}

export async function apiFetch<T>(path: string, opts?: { token?: string; init?: RequestInit }): Promise<T> {
  const baseUrl = getApiBaseUrl()
  const token = opts?.token
  const init = opts?.init ?? {}
  const headers = new Headers(init.headers)
  headers.set('Accept', 'application/json')
  if (!headers.has('Content-Type') && init.body) headers.set('Content-Type', 'application/json')
  if (token) headers.set('Authorization', `Bearer ${token}`)

  const controller = new AbortController()
  const timeoutMs = getApiTimeoutMs()
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs)
  if (init.signal) init.signal.addEventListener('abort', () => controller.abort(), { once: true })

  let res: Response
  try {
    res = await fetch(`${baseUrl}${path}`, { ...init, headers, signal: controller.signal })
  } catch (e: unknown) {
    const isAbort = controller.signal.aborted
    const message = isAbort
      ? `Request timed out after ${timeoutMs}ms. Is the API running at ${baseUrl}?`
      : `Network error. Is the API running at ${baseUrl}?`
    const err: ApiError = { status: 0, message, details: e }
    throw err
  } finally {
    clearTimeout(timeoutId)
  }
  if (res.ok) return (await parseJsonSafe(res)) as T

  const details = await parseJsonSafe(res)
  const message =
    (details && typeof details === 'object' && 'detail' in details && (details as any).detail) ||
    res.statusText ||
    'Request failed'

  const err: ApiError = { status: res.status, message: String(message), details }
  throw err
}

export async function login(email: string, password: string): Promise<TokenResponse> {
  const body = JSON.stringify({ email, password })
  try {
    return await apiFetch<TokenResponse>('/api/v1/admin/login', {
      init: { method: 'POST', body },
    })
  } catch (e: unknown) {
    const status = (e as ApiError | undefined)?.status
    if (status === 404 || status === 405) {
      return apiFetch<TokenResponse>('/api/v1/auth/login', {
        init: { method: 'POST', body },
      })
    }
    throw e
  }
}

export async function listUsers(token: string) {
  return apiFetch<UserOut[]>('/api/v1/users/?skip=0&limit=1000', { token })
}

export async function listDoctors(token: string, opts?: { availableOnly?: boolean; specialistType?: SpecialistTypeApi }) {
  const params = new URLSearchParams()
  if (opts?.availableOnly) params.set('available_only', 'true')
  if (opts?.specialistType) params.set('specialist_type', opts.specialistType)
  const qs = params.toString()
  return apiFetch<UserOut[]>(`/api/v1/users/doctors${qs ? `?${qs}` : ''}`, { token })
}

export async function listBookings(token: string) {
  return apiFetch<BookingOut[]>('/api/v1/bookings/', { token })
}

export async function listSessions(token: string) {
  return apiFetch<SessionOut[]>('/api/v1/sessions/', { token })
}

export async function listFeedback(token: string) {
  return apiFetch<FeedbackOut[]>('/api/v1/feedback/', { token })
}

export async function listConversations(token: string) {
  return apiFetch<ConversationListItem[]>('/api/v1/chat/conversations', { token })
}

export async function sendConversationMessage(token: string, conversationId: string, body: string) {
  return apiFetch(`/api/v1/chat/conversations/${conversationId}/messages`, {
    token,
    init: { method: 'POST', body: JSON.stringify({ body }) },
  })
}

export async function assignDoctorToSession(
  token: string,
  sessionId: string,
  body: { doctor_id: string; scheduled_at: string; meeting_link?: string | null }
) {
  return apiFetch<SessionOut>(`/api/v1/sessions/${sessionId}/assign`, {
    token,
    init: { method: 'POST', body: JSON.stringify(body) },
  })
}

export async function updateSession(
  token: string,
  sessionId: string,
  body: { status?: SessionOut['status'] | null; meeting_link?: string | null; scheduled_at?: string | null; notes?: string | null }
) {
  return apiFetch<SessionOut>(`/api/v1/sessions/${sessionId}`, {
    token,
    init: { method: 'PATCH', body: JSON.stringify(body) },
  })
}

