// UI Types (derived from API)
export type ConsultationStatus = 'pending' | 'assigned' | 'scheduled' | 'in-progress' | 'completed' | 'cancelled'
export type SpecialistType = 'Psychologist' | 'Psychiatrist' | 'Cleric' | 'Therapist' | 'General'
export type PaymentStatus = 'pending' | 'proof_submitted' | 'paid' | 'refunded' | 'none'

export interface Client {
  id: string
  name: string
  email: string
  phone: string
  avatar: string
}

export interface Specialist {
  id: string
  name: string
  type: SpecialistType
  email: string
  phone: string
  avatar: string
  availability: {
    day: string
    slots: string[]
  }[]
  isAvailable: boolean
}

export interface ConsultationRequest {
  id: string // session id (API)
  bookingId: string
  client: Client
  challengeDescription: string
  status: ConsultationStatus
  requestedDate: string
  consentGiven?: boolean
  consentTimestamp?: string | null
  sessionType?: 'audio' | 'video' | 'physical'
  durationMinutes?: number
  physicalVenue?: 'home' | 'office' | null
  physicalLocationAddress?: string | null
  physicalNotes?: string | null
  assignedSpecialist?: Specialist
  scheduledDate?: string
  scheduledTime?: string
  meetingLink?: string
  meetingPlatform?: 'zoom' | 'google-meet'
  sessionReport?: string
  paymentStatus?: PaymentStatus
  feedback?: {
    rating: number
    comment: string
    date: string
  }
}

// Helper functions
export const getStatusColor = (status: ConsultationStatus) => {
  switch (status) {
    case 'pending':
      return 'bg-warning/20 text-warning-foreground border-warning/30'
    case 'assigned':
      return 'bg-chart-2/20 text-chart-2 border-chart-2/30'
    case 'scheduled':
      return 'bg-primary/20 text-primary border-primary/30'
    case 'in-progress':
      return 'bg-chart-1/20 text-chart-1 border-chart-1/30'
    case 'completed':
      return 'bg-success/20 text-success border-success/30'
    case 'cancelled':
      return 'bg-destructive/20 text-destructive border-destructive/30'
    default:
      return 'bg-muted text-muted-foreground'
  }
}

export const formatDate = (dateString: string) => {
  const date = new Date(dateString)
  return date.toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
  })
}

export const safeAvatarUrl = (seed: string) =>
  `https://api.dicebear.com/7.x/avataaars/svg?seed=${encodeURIComponent(seed || 'User')}`

