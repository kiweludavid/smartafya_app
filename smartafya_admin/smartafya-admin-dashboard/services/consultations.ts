import { api } from '@/services/api'
import type { BookingOut, PaymentOut, SessionOut, UserOut } from '@/lib/api'
import type { ConsultationRequest, ConsultationStatus, Specialist, SpecialistType } from '@/lib/data'
import { safeAvatarUrl } from '@/lib/data'

export type ConsultationStatusApi = 'pending' | 'scheduled' | 'completed' | 'cancelled'

export type ConsultationApi = {
  id: string
  booking_id: string
  booking_status?: BookingOut['status']
  consent_given?: boolean
  consent_timestamp?: string | null
  session_type?: BookingOut['session_type']
  duration_minutes?: number
  physical_venue?: BookingOut['physical_venue']
  physical_location_address?: BookingOut['physical_location_address']
  physical_notes?: BookingOut['physical_notes']
  client_id?: string
  client_name: string
  client_email?: string
  client_phone?: string
  specialist_name: string
  specialist_id?: string
  specialist_type?: string | null
  status: ConsultationStatusApi
  date: string
  challenge_description?: string
  scheduled_at?: string | null
  meeting_link?: string | null
  session_notes?: string | null
  payment_status?: string | null
}

function mapSessionStatus(s: SessionOut['status']): ConsultationStatusApi {
  if (s === 'scheduled') return 'scheduled'
  if (s === 'completed' || s === 'transferred') return 'completed'
  if (s === 'cancelled') return 'cancelled'
  return 'pending'
}

export async function listConsultations(): Promise<ConsultationApi[]> {
  const [sessionsRes, bookingsRes, usersRes, paymentsRes] = await Promise.all([
    api.get<SessionOut[]>('/api/v1/sessions/'),
    api.get<BookingOut[]>('/api/v1/bookings/'),
    api.get<UserOut[]>('/api/v1/users/?skip=0&limit=1000'),
    api.get<PaymentOut[]>('/api/v1/payments/'),
  ])

  const bookingsMap = new Map(bookingsRes.data.map((b) => [b.id, b]))
  const usersMap = new Map(usersRes.data.map((u) => [u.id, u]))
  const paymentsMap = new Map(paymentsRes.data.map((p) => [p.session_id, p]))

  return sessionsRes.data.map((s) => {
    const booking = bookingsMap.get(s.booking_id)
    const client = usersMap.get(s.client_id)
    const doctor = s.doctor_id ? usersMap.get(s.doctor_id) : undefined
    const payment = paymentsMap.get(s.id)
    return {
      id: s.id,
      booking_id: s.booking_id,
      booking_status: booking?.status,
      consent_given: booking?.consent_given,
      consent_timestamp: booking?.consent_timestamp ? String(booking.consent_timestamp) : null,
      session_type: booking?.session_type,
      duration_minutes: booking?.duration_minutes,
      physical_venue: booking?.physical_venue ?? null,
      physical_location_address: booking?.physical_location_address ?? null,
      physical_notes: booking?.physical_notes ?? null,
      client_id: s.client_id,
      client_name: client?.full_name ?? 'Unknown client',
      client_email: client?.email,
      client_phone: client?.phone ?? undefined,
      specialist_name: doctor?.full_name ?? '',
      specialist_id: doctor?.id,
      specialist_type: doctor?.specialist_type ?? null,
      status: mapSessionStatus(s.status),
      date: booking?.created_at ?? s.created_at,
      challenge_description: booking?.mental_health_description,
      scheduled_at: s.scheduled_at,
      meeting_link: s.meeting_link,
      session_notes: s.notes,
      payment_status: payment?.status ?? null,
    }
  })
}

export async function cancelConsultationSession(args: { consultation_id: string }) {
  // Admins are allowed to PATCH sessions.
  // Used for "Decline & return to applicant" when consent is missing.
  await api.patch(`/api/v1/sessions/${args.consultation_id}`, { status: 'cancelled' })
}

export async function updateConsultationNotes(args: { consultation_id: string; notes: string | null }) {
  await api.patch(`/api/v1/sessions/${args.consultation_id}`, { notes: args.notes })
}

const consultationStatusToUi = (status: string): ConsultationStatus => {
  switch (status) {
    case 'pending':
      return 'pending'
    case 'scheduled':
      return 'scheduled'
    case 'completed':
      return 'completed'
    case 'cancelled':
      return 'cancelled'
    default:
      return 'pending'
  }
}

function specialistTypeFromApi(t: string | null | undefined): SpecialistType {
  switch (String(t || '').toLowerCase()) {
    case 'psychologist':
      return 'Psychologist'
    case 'psychiatrist':
      return 'Psychiatrist'
    case 'therapist':
      return 'Therapist'
    case 'cleric':
      return 'Cleric'
    default:
      return 'General'
  }
}

function makeSpecialistFromApi(name: string, id?: string, specialist_type?: string | null): Specialist {
  return {
    id: id || name,
    name,
    type: specialistTypeFromApi(specialist_type),
    email: '',
    phone: '',
    avatar: safeAvatarUrl(name),
    availability: [],
    isAvailable: true,
  }
}

/** Map API consultation row to dashboard UI model (session-centric). */
export function mapConsultationApiToUi(c: ConsultationApi): ConsultationRequest {
  const baseStatus = consultationStatusToUi(c.status)
  // Treat a request as "assigned" only when the backend provides a real specialist id.
  // Some APIs may include a placeholder `specialist_name` even when unassigned.
  const specialistId = String(c.specialist_id ?? '').trim()
  const hasAssignee =
    specialistId.length > 0 &&
    specialistId !== '0' &&
    specialistId.toLowerCase() !== 'null' &&
    specialistId.toLowerCase() !== 'undefined' &&
    specialistId.toLowerCase() !== 'none'
  // Dashboard rule: requests that are not yet scheduled remain "pending" even if a specialist is selected/linked.
  // We still surface the specialist in the UI, but keep the status as pending until scheduling.
  const status: ConsultationStatus = baseStatus

  let scheduledDate: string | undefined
  let scheduledTime: string | undefined
  if (c.scheduled_at) {
    const d = new Date(c.scheduled_at)
    if (!Number.isNaN(d.getTime())) {
      scheduledDate = d.toISOString().slice(0, 10)
      scheduledTime = d.toISOString().slice(11, 16)
    }
  }

  return {
    id: c.id,
    bookingId: c.booking_id || c.id,
    client: {
      id: c.client_id || c.client_name || c.id,
      name: c.client_name || 'Unknown client',
      email: String(c.client_email || ''),
      phone: String(c.client_phone || ''),
      avatar: safeAvatarUrl(c.client_name || c.id),
    },
    challengeDescription: String(c.challenge_description || '').trim() || '(No description provided)',
    status,
    requestedDate: c.date,
    consentGiven: c.consent_given,
    consentTimestamp: c.consent_timestamp ?? null,
    sessionType: c.session_type,
    durationMinutes: c.duration_minutes,
    physicalVenue: c.physical_venue ?? null,
    physicalLocationAddress: c.physical_location_address ?? null,
    physicalNotes: c.physical_notes ?? null,
    assignedSpecialist:
      hasAssignee && String(c.specialist_name || '').trim()
        ? makeSpecialistFromApi(c.specialist_name, c.specialist_id, c.specialist_type)
        : undefined,
    scheduledDate,
    scheduledTime,
    meetingLink: c.meeting_link ?? undefined,
    sessionReport: String(c.session_notes || '').trim() || undefined,
    paymentStatus: (String(c.payment_status || '').toLowerCase().trim() as any) || 'none',
  }
}
