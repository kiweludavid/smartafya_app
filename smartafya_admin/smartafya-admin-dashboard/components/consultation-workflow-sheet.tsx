'use client'

import { useEffect, useMemo, useState } from 'react'
import { Calendar, ClipboardList, Link2, Mail, UserCheck } from 'lucide-react'
import { Sheet, SheetContent, SheetDescription, SheetHeader, SheetTitle } from '@/components/ui/sheet'
import { Card, CardContent } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Separator } from '@/components/ui/separator'
import { Spinner } from '@/components/ui/spinner'
import { StepIndicator } from '@/components/step-indicator'
import { ConsultationRequest, ConsultationStatus, Specialist, SpecialistType, formatDate, getStatusColor, safeAvatarUrl } from '@/lib/data'
import { listSpecialists } from '@/services/specialists'
import { scheduleSession, sendSessionInstructions } from '@/services/scheduling'
import { cancelConsultationSession, updateConsultationNotes } from '@/services/consultations'
import type { SpecialistTypeApi } from '@/lib/api'
import { toast } from 'sonner'
import { cn } from '@/lib/utils'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import axios from 'axios'

type WizardStepKey = 'assign' | 'time' | 'schedule' | 'instructions'

const specialistTypeToUi = (t: string | null | undefined): SpecialistType => {
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

const specialistTypeToApi = (t: SpecialistType): SpecialistTypeApi => {
  switch (t) {
    case 'Psychologist':
      return 'psychologist'
    case 'Psychiatrist':
      return 'psychiatrist'
    case 'Therapist':
      return 'therapist'
    case 'Cleric':
      return 'cleric'
    default:
      return 'general'
  }
}

const toUiSpecialist = (raw: any): Specialist => {
  const name = String(raw?.name || raw?.full_name || 'Unknown specialist')
  return {
    id: String(raw?.id || name),
    name,
    type: specialistTypeToUi(raw?.type || raw?.specialist_type),
    email: String(raw?.email || ''),
    phone: String(raw?.phone || ''),
    avatar: safeAvatarUrl(name),
    availability: Array.isArray(raw?.availability) ? raw.availability : [],
    isAvailable: raw?.is_available == null ? true : Boolean(raw.is_available),
  }
}

const generateMeetingLink = (platform: 'zoom' | 'google-meet') => {
  if (platform === 'zoom') return `https://zoom.us/j/${Math.random().toString().slice(2, 12)}`
  return `https://meet.google.com/${Math.random().toString(36).slice(2, 5)}-${Math.random().toString(36).slice(2, 6)}-${Math.random().toString(36).slice(2, 5)}`
}

export function ConsultationWorkflowSheet({
  open,
  onOpenChange,
  consultation,
  onUpdate,
  pendingTransferRequest,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
  consultation: ConsultationRequest | null
  onUpdate: (next: ConsultationRequest) => void
  pendingTransferRequest?: {
    id: string
    session_id: string
    from_doctor_id: string
    to_doctor_id: string
    reason: string
    status: string
    created_at: string
    updated_at: string
  } | null
}) {
  const [step, setStep] = useState<WizardStepKey>('assign')
  const [isLoadingSpecialists, setIsLoadingSpecialists] = useState(false)
  const [specialists, setSpecialists] = useState<Specialist[]>([])
  const [specialistType, setSpecialistType] = useState<SpecialistType>('Psychologist')
  const [showOnlyAvailable, setShowOnlyAvailable] = useState(true)
  const [selectedSpecialistId, setSelectedSpecialistId] = useState<string>('')

  const [selectedSlot, setSelectedSlot] = useState<{ date: string; time: string } | null>(null)

  const [scheduleDate, setScheduleDate] = useState('')
  const [scheduleTime, setScheduleTime] = useState('')
  const [durationMinutes, setDurationMinutes] = useState(45)

  const [platform, setPlatform] = useState<'zoom' | 'google-meet'>('google-meet')
  const [meetingLink, setMeetingLink] = useState('')

  const [instructions, setInstructions] = useState('')
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [paymentAmount, setPaymentAmount] = useState('')
  const [paymentInstructions, setPaymentInstructions] = useState('')

  useEffect(() => {
    if (!open) return
    setStep('assign')
  }, [open])

  useEffect(() => {
    if (!open) return
    if (!consultation) return

    setSelectedSpecialistId(consultation.assignedSpecialist?.id ?? '')
    setScheduleDate(consultation.scheduledDate ?? '')
    setScheduleTime(consultation.scheduledTime ?? '')
    setDurationMinutes(45)
    setPlatform(consultation.meetingPlatform ?? 'google-meet')
    setMeetingLink(consultation.meetingLink ?? '')
    setSelectedSlot(null)
    setInstructions('')
    setPaymentAmount('')
    setPaymentInstructions('')
  }, [open, consultation])

  useEffect(() => {
    if (!open) return
    setIsLoadingSpecialists(true)
    const apiType = specialistTypeToApi(specialistType)
    listSpecialists({ specialistType: apiType, availableOnly: showOnlyAvailable })
      .then((rows) => setSpecialists(rows.map(toUiSpecialist)))
      .catch(() => toast.error('Failed to load specialists'))
      .finally(() => setIsLoadingSpecialists(false))
  }, [open, specialistType, showOnlyAvailable])

  const selectedSpecialist = useMemo(() => {
    return specialists.find((s) => s.id === selectedSpecialistId) ?? null
  }, [specialists, selectedSpecialistId])

  // Backend already filters by type/availability; keep `filteredSpecialists` as the
  // active list for the dropdown so consumers don't break.
  const filteredSpecialists = specialists

  const availabilitySlots = useMemo(() => {
    if (!selectedSpecialist) return []

    // If backend provides structured availability, prefer it.
    const avail = selectedSpecialist.availability
    if (Array.isArray(avail) && avail.length > 0) {
      const flattened: { date: string; time: string; label: string }[] = []
      for (const day of avail) {
        const date = String((day as any)?.day || '')
        const slots = Array.isArray((day as any)?.slots) ? (day as any).slots : []
        for (const t of slots) flattened.push({ date, time: String(t), label: `${date} • ${t}` })
      }
      return flattened.slice(0, 16)
    }

    // Fallback: allow picking from common slots (still enforces a real choice in the flow).
    const today = new Date()
    const nextDays = Array.from({ length: 5 }, (_, i) => {
      const d = new Date(today)
      d.setDate(d.getDate() + i + 1)
      return d.toISOString().slice(0, 10)
    })
    const times = ['09:00', '10:00', '11:00', '14:00', '15:00', '16:00']
    return nextDays.flatMap((date) => times.map((time) => ({ date, time, label: `${date} • ${time}` })))
  }, [selectedSpecialist])

  const groupedSlots = useMemo(() => {
    const byDate = new Map<string, { date: string; time: string }[]>()
    for (const s of availabilitySlots) {
      const dateKey = String(s.date || '').trim()
      if (!dateKey) continue
      const arr = byDate.get(dateKey) ?? []
      arr.push({ date: s.date, time: s.time })
      byDate.set(dateKey, arr)
    }
    return Array.from(byDate.entries())
      .map(([date, slots]) => ({
        date,
        slots: slots
          .filter((x) => String(x.time || '').trim())
          .sort((a, b) => String(a.time).localeCompare(String(b.time))),
      }))
      .sort((a, b) => String(a.date).localeCompare(String(b.date)))
  }, [availabilitySlots])

  const statusLabel = (s: ConsultationStatus) => s.replace('-', ' ')

  const steps = useMemo(() => {
    const hasAssigned = Boolean(consultation?.assignedSpecialist)
    const hasSlot = Boolean(selectedSlot || (scheduleDate && scheduleTime))
    const hasScheduled = Boolean(consultation?.status === 'scheduled' || consultation?.status === 'completed')
    const hasInstructions = Boolean(instructions.trim().length > 0)
    return [
      { key: 'assign', label: 'Assign Specialist', description: hasAssigned ? 'Selected' : 'Required', isComplete: hasAssigned },
      { key: 'time', label: 'Pick Time', description: hasSlot ? 'Chosen' : 'Required', isComplete: hasSlot },
      { key: 'schedule', label: 'Schedule', description: hasScheduled ? 'Scheduled' : 'Confirm', isComplete: hasScheduled },
      { key: 'instructions', label: 'Instructions', description: hasInstructions ? 'Drafted' : 'Send', isComplete: false },
    ]
  }, [consultation, selectedSlot, scheduleDate, scheduleTime, instructions])

  const canMoveToTime = Boolean(selectedSpecialist)
  const canMoveToSchedule = Boolean(selectedSpecialist) && Boolean(selectedSlot || (scheduleDate && scheduleTime))

  const isConsentMissing = consultation?.consentGiven === false
  const isPhysicalSession = consultation?.sessionType === 'physical'

  const handleAssign = () => {
    if (!consultation) return
    if (isConsentMissing) {
      toast.error('Consent is not filled. Decline and return this request to the applicant.')
      return
    }
    if (!selectedSpecialist) {
      toast.error('Select a specialist')
      return
    }
    const nextStatus: ConsultationStatus = consultation.status === 'pending' ? 'assigned' : consultation.status
    onUpdate({ ...consultation, assignedSpecialist: selectedSpecialist, status: nextStatus })
    toast.success('Specialist assigned')
    setStep('time')
  }

  const handleDeclineMissingConsent = async () => {
    if (!consultation) return
    setIsSubmitting(true)
    try {
      await cancelConsultationSession({ consultation_id: consultation.id })
      if (consultation.client.id) {
        await sendSessionInstructions({
          consultation_id: consultation.id,
          body: [
            'Your consultation request was returned because consent was not completed.',
            'Please review and accept the consent/terms, then submit the request again.',
          ].join('\n'),
        })
      }
      toast.success('Request declined and returned to applicant')
      onUpdate({ ...consultation, status: 'cancelled' })
      onOpenChange(false)
    } catch {
      toast.error('Failed to decline request')
    } finally {
      setIsSubmitting(false)
    }
  }

  const handleTransferSelectProposed = () => {
    if (!pendingTransferRequest) return
    setSelectedSpecialistId(String(pendingTransferRequest.to_doctor_id))
    setStep('assign')
    toast.message('Proposed specialist selected')
  }

  const handleReassignKeepSchedule = async (targetSpecialistId: string) => {
    if (!consultation) return
    const specialist = specialists.find((s) => String(s.id) === String(targetSpecialistId)) ?? selectedSpecialist
    if (!specialist) {
      toast.error('Select a specialist to reassign')
      return
    }
    if (!scheduleDate || !scheduleTime) {
      toast.error('This session has no scheduled date/time to preserve')
      return
    }
    setIsSubmitting(true)
    try {
      await scheduleSession({
        consultation_id: consultation.id,
        specialist_id: specialist.id,
        specialist_name: specialist.name,
        date: scheduleDate,
        time: scheduleTime,
        meeting_platform: platform,
        meeting_link: meetingLink || consultation.meetingLink || undefined,
      })
      onUpdate({
        ...consultation,
        assignedSpecialist: specialist,
        status: 'scheduled',
        scheduledDate: scheduleDate,
        scheduledTime: scheduleTime,
        meetingPlatform: platform,
        meetingLink: meetingLink || consultation.meetingLink || undefined,
      })
      toast.success('Session reassigned')
    } catch {
      toast.error('Failed to reassign session')
    } finally {
      setIsSubmitting(false)
    }
  }

  const handlePickSlot = (slot: { date: string; time: string }) => {
    setSelectedSlot(slot)
    setScheduleDate(slot.date)
    setScheduleTime(slot.time)
  }

  const handleGenerateLink = () => {
    const next = generateMeetingLink(platform)
    setMeetingLink(next)
    toast.success('Meeting link generated')
  }

  const handleConfirmSchedule = async () => {
    if (!consultation) return
    if (!selectedSpecialist) {
      toast.error('Assign a specialist first')
      setStep('assign')
      return
    }
    if (!scheduleDate || !scheduleTime) {
      toast.error('Select a date and time')
      setStep('time')
      return
    }
    if (!isPhysicalSession && !meetingLink) {
      toast.error('Generate or enter a meeting link')
      return
    }

    setIsSubmitting(true)
    try {
      await scheduleSession({
        consultation_id: consultation.id,
        specialist_id: selectedSpecialist.id,
        specialist_name: selectedSpecialist.name,
        date: scheduleDate,
        time: scheduleTime,
        duration_minutes: durationMinutes,
        meeting_platform: platform,
        meeting_link: isPhysicalSession ? undefined : meetingLink,
        instructions: instructions.trim() ? instructions.trim() : undefined,
      })

      onUpdate({
        ...consultation,
        assignedSpecialist: selectedSpecialist,
        status: 'scheduled',
        scheduledDate: scheduleDate,
        scheduledTime: scheduleTime,
        meetingPlatform: isPhysicalSession ? undefined : platform,
        meetingLink: isPhysicalSession ? undefined : meetingLink,
      })
      toast.success('Session scheduled')
      setStep('instructions')
    } catch {
      toast.error('Failed to schedule session')
    } finally {
      setIsSubmitting(false)
    }
  }

  const handleSavePaymentInfo = async () => {
    if (!consultation) return
    const amount = paymentAmount.trim()
    const instr = paymentInstructions.trim()
    if (!amount && !instr) {
      toast.error('Enter payment amount or instructions')
      return
    }
    const nextNotes = [
      consultation.sessionReport ? consultation.sessionReport.trim() : '',
      '',
      '--- Payment (admin) ---',
      amount ? `Amount agreed: ${amount}` : '',
      instr ? `Instructions: ${instr}` : '',
    ]
      .filter(Boolean)
      .join('\n')
      .trim()
    setIsSubmitting(true)
    try {
      await updateConsultationNotes({ consultation_id: consultation.id, notes: nextNotes })
      onUpdate({ ...consultation, sessionReport: nextNotes })
      toast.success('Payment info saved')
    } catch {
      toast.error('Failed to save payment info')
    } finally {
      setIsSubmitting(false)
    }
  }

  const handleSendPaymentInstructions = async () => {
    if (!consultation) return
    const amount = paymentAmount.trim()
    const instr = paymentInstructions.trim()
    const body = [
      'Payment instructions for your physical session:',
      amount ? `Amount agreed: ${amount}` : '',
      instr ? instr : '',
    ]
      .filter(Boolean)
      .join('\n')
      .trim()
    if (!body) {
      toast.error('Enter payment amount or instructions')
      return
    }
    if (!consultation.client.id) {
      toast.error('Client id missing for this consultation')
      return
    }
    setIsSubmitting(true)
    try {
      await sendSessionInstructions({ consultation_id: consultation.id, body })
      toast.success('Payment instructions sent')
    } catch (err: unknown) {
      toast.error(err instanceof Error ? err.message : 'Failed to send payment instructions')
    } finally {
      setIsSubmitting(false)
    }
  }

  const handleSendInstructions = async () => {
    if (!consultation) return
    const trimmed = instructions.trim()
    if (!trimmed) {
      toast.error('Write instructions first')
      return
    }
    if (!consultation.client.id) {
      toast.error('Client id missing for this consultation')
      return
    }
    setIsSubmitting(true)
    try {
      // Best-effort: persist on the session so the report tab keeps a record, then deliver to chat.
      // Some deployments may forbid admins from PATCHing sessions; don't block messaging on that.
      try {
        await scheduleSession({ consultation_id: consultation.id, instructions: trimmed })
      } catch (err: unknown) {
        if (!(axios.isAxiosError(err) && err.response?.status === 403)) throw err
      }
      await sendSessionInstructions({ consultation_id: consultation.id, body: trimmed })
      onUpdate({ ...consultation, sessionReport: trimmed })
      toast.success('Instructions sent to client')
    } catch (err: unknown) {
      toast.error(err instanceof Error ? err.message : 'Failed to send instructions')
    } finally {
      setIsSubmitting(false)
    }
  }

  const getInitials = (name: string) =>
    String(name || '')
      .trim()
      .split(/\s+/)
      .filter(Boolean)
      .slice(0, 2)
      .map((n) => n[0]!.toUpperCase())
      .join('')

  const activeSpecialistCard = selectedSpecialist ?? consultation?.assignedSpecialist ?? null

  if (!consultation) {
    return (
      <Sheet open={open} onOpenChange={onOpenChange}>
        <SheetContent className="sm:max-w-xl">
          <SheetHeader>
            <SheetTitle>Consultation details</SheetTitle>
            <SheetDescription>Select a consultation to view details.</SheetDescription>
          </SheetHeader>
        </SheetContent>
      </Sheet>
    )
  }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent className="bg-[#F8FAFC] p-0 sm:max-w-3xl">
        <div className="border-b border-slate-200 bg-white/70 px-5 py-4 backdrop-blur sm:px-6">
          <SheetHeader className="space-y-0 p-0">
            <div className="flex items-start justify-between gap-4">
              <div className="min-w-0">
                <div className="text-xs font-medium text-slate-500">Request #{consultation.id}</div>
                <SheetTitle className="mt-1 text-lg font-semibold tracking-tight text-slate-900">
                  Assign Specialist &amp; Schedule Session
                </SheetTitle>
                <SheetDescription className="mt-1 text-sm text-slate-500">
                  Submitted {formatDate(consultation.requestedDate)}
                </SheetDescription>
              </div>
            </div>
          </SheetHeader>

          <StepIndicator steps={steps} activeKey={step} className="mt-4" />
        </div>

        <div className="flex-1 overflow-y-auto px-5 pb-8 pt-5 sm:px-6">
          {isPhysicalSession && (
            <Card className="mb-4 border-slate-200 bg-white shadow-sm">
              <CardContent className="p-5 sm:p-6">
                <div className="text-sm font-semibold text-slate-900">Physical session (manual arrangement)</div>
                <div className="mt-1 text-sm text-slate-600">
                  Admin arranges the visit manually. Payment is agreed with the client, and instructions are sent here.
                </div>
                <div className="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-2">
                  <div className="rounded-xl border border-slate-200 bg-white p-4 shadow-sm">
                    <div className="text-xs text-slate-500">Venue</div>
                    <div className="mt-1 text-sm font-medium text-slate-900">
                      {consultation.physicalVenue ? consultation.physicalVenue : '—'}
                    </div>
                  </div>
                  <div className="rounded-xl border border-slate-200 bg-white p-4 shadow-sm">
                    <div className="text-xs text-slate-500">Address / Location</div>
                    <div className="mt-1 text-sm font-medium text-slate-900">
                      {consultation.physicalLocationAddress ? consultation.physicalLocationAddress : '—'}
                    </div>
                  </div>
                </div>
                {consultation.physicalNotes && (
                  <div className="mt-3 rounded-xl border border-slate-200 bg-slate-50/60 p-4 text-sm text-slate-700">
                    {consultation.physicalNotes}
                  </div>
                )}
              </CardContent>
            </Card>
          )}
          {isConsentMissing && (
            <Card className="mb-4 border-amber-200 bg-white shadow-sm">
              <CardContent className="p-5 sm:p-6">
                <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                  <div className="min-w-0">
                    <div className="text-sm font-semibold text-slate-900">Consent missing</div>
                    <div className="mt-1 text-sm text-slate-600">
                      This request cannot be assigned until the applicant completes consent.
                    </div>
                  </div>
                  <div className="flex flex-wrap gap-2">
                    <Button
                      type="button"
                      variant="outline"
                      onClick={() => {
                        if (!consultation?.client.id) return toast.error('Client id missing for this consultation')
                        void sendSessionInstructions({
                          consultation_id: consultation.id,
                          body: 'Please complete consent/terms to proceed with your consultation request.',
                        })
                          .then(() => toast.success('Reminder sent'))
                          .catch((err) => toast.error(err instanceof Error ? err.message : 'Failed to send reminder'))
                      }}
                      disabled={isSubmitting}
                      className="h-10 rounded-xl border-slate-200 bg-white hover:bg-slate-50"
                    >
                      Send reminder
                    </Button>
                    <Button
                      type="button"
                      onClick={() => void handleDeclineMissingConsent()}
                      disabled={isSubmitting}
                      className="h-10 rounded-xl bg-amber-600 px-4 font-medium text-white shadow-sm hover:bg-amber-700 focus-visible:ring-2 focus-visible:ring-amber-600/20"
                    >
                      {isSubmitting ? <Spinner className="mr-2" /> : null}
                      Decline &amp; return
                    </Button>
                  </div>
                </div>
              </CardContent>
            </Card>
          )}
          {pendingTransferRequest && (
            <Card className="mb-4 border-blue-200 bg-white shadow-sm">
              <CardContent className="p-5 sm:p-6">
                <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                  <div className="min-w-0">
                    <div className="text-sm font-semibold text-slate-900">Transfer requested by doctor</div>
                    <div className="mt-1 text-sm text-slate-600">
                      Reason: <span className="font-medium text-slate-900">{pendingTransferRequest.reason}</span>
                    </div>
                    <div className="mt-1 text-xs text-slate-500">Request ID: {pendingTransferRequest.id}</div>
                  </div>
                  <div className="flex flex-wrap gap-2">
                    <Button
                      type="button"
                      variant="outline"
                      onClick={handleTransferSelectProposed}
                      className="h-10 rounded-xl border-slate-200 bg-white hover:bg-slate-50"
                    >
                      Select proposed specialist
                    </Button>
                    {consultation.scheduledDate && consultation.scheduledTime && (
                      <Button
                        type="button"
                        onClick={() => void handleReassignKeepSchedule(String(pendingTransferRequest.to_doctor_id))}
                        disabled={isSubmitting}
                        className="h-10 rounded-xl bg-blue-600 px-4 font-medium text-white shadow-sm hover:bg-blue-700 focus-visible:ring-2 focus-visible:ring-blue-600/20"
                      >
                        {isSubmitting ? <Spinner className="mr-2" /> : null}
                        Reassign now
                      </Button>
                    )}
                  </div>
                </div>
              </CardContent>
            </Card>
          )}

          {/* SECTION A: Client Info */}
          <Card className="border-slate-200 bg-white shadow-sm">
            <CardContent className="p-5 sm:p-6">
              <div className="flex items-start justify-between gap-4">
                <div className="min-w-0">
                  <div className="text-sm font-semibold text-slate-900">{consultation.client.name}</div>
                  <div className="mt-1 text-xs text-slate-500">Client ID: {consultation.client.id}</div>
                </div>
                <div className="flex gap-2">
                  <Button
                    variant="outline"
                    size="sm"
                    className="gap-2 rounded-xl border-slate-200 bg-white hover:bg-slate-50"
                    disabled={!consultation.client.email}
                  >
                    <Mail className="size-4" /> Email
                  </Button>
                </div>
              </div>
              {(consultation.client.email || consultation.client.phone) && (
                <div className="mt-3 grid grid-cols-2 gap-3 text-sm">
                  <div className="rounded-xl border border-slate-200 bg-white p-4 shadow-sm">
                    <div className="text-xs text-slate-500">Email</div>
                    <div className="mt-1 truncate font-medium text-slate-900">{consultation.client.email || '—'}</div>
                  </div>
                  <div className="rounded-xl border border-slate-200 bg-white p-4 shadow-sm">
                    <div className="text-xs text-slate-500">Phone</div>
                    <div className="mt-1 truncate font-medium text-slate-900">{consultation.client.phone || '—'}</div>
                  </div>
                </div>
              )}
            </CardContent>
          </Card>

          {/* SECTION B: Challenge Description */}
          <Card className="mt-4 border-slate-200 bg-white shadow-sm">
            <CardContent className="p-5 sm:p-6">
              <div className="flex items-center gap-2 text-sm font-semibold text-slate-900">
                <ClipboardList className="size-4 text-slate-400" />
                Challenge
              </div>
              <p className="mt-3 whitespace-pre-wrap text-sm leading-relaxed text-slate-600">
                {consultation.challengeDescription}
              </p>
            </CardContent>
          </Card>

          {/* SECTION C: Assign Specialist */}
          <Card className="mt-6 border-slate-200 bg-white shadow-sm">
            <CardContent className="p-5 sm:p-6">
              <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
                <div className="min-w-0">
                  <div className="text-base font-semibold text-slate-900">Assign specialist</div>
                  <div className="mt-1 text-sm text-slate-500">
                    Choose a specialist type and confirm an available provider for this request.
                  </div>
                </div>

                <div className="rounded-xl border border-slate-200 bg-slate-50/60 p-3 shadow-sm sm:w-[320px]">
                  <div className="flex items-center gap-3">
                    <Avatar className="size-10 border border-slate-200 bg-white">
                      <AvatarImage src={activeSpecialistCard?.avatar} alt={activeSpecialistCard?.name || 'Specialist'} />
                      <AvatarFallback className="text-xs font-semibold text-slate-600">
                        {activeSpecialistCard ? getInitials(activeSpecialistCard.name) : 'DR'}
                      </AvatarFallback>
                    </Avatar>
                    <div className="min-w-0 flex-1">
                      <div className="truncate text-sm font-semibold text-slate-900">
                        {activeSpecialistCard?.name || 'No specialist selected'}
                      </div>
                      <div className="mt-0.5 flex items-center gap-2 text-xs text-slate-500">
                        <span className="truncate">{activeSpecialistCard?.type || '—'}</span>
                        <span className="text-slate-300">•</span>
                        <span
                          className={cn(
                            'inline-flex items-center rounded-full border px-2 py-0.5 font-medium',
                            activeSpecialistCard
                              ? activeSpecialistCard.isAvailable
                                ? 'border-emerald-200 bg-white text-emerald-700'
                                : 'border-slate-200 bg-white text-slate-600'
                              : 'border-slate-200 bg-white text-slate-600'
                          )}
                        >
                          {activeSpecialistCard ? (activeSpecialistCard.isAvailable ? 'Available' : 'Unavailable') : '—'}
                        </span>
                      </div>
                    </div>
                    {consultation.assignedSpecialist && (
                      <div className="hidden items-center gap-2 text-xs font-medium text-slate-600 sm:flex">
                        <UserCheck className="size-4 text-slate-400" />
                        Assigned
                      </div>
                    )}
                  </div>
                </div>
              </div>

              <div className="mt-5 grid grid-cols-1 gap-4 sm:grid-cols-2">
                <div className="space-y-2">
                  <Label className="text-sm font-medium text-slate-700">Specialist type</Label>
                  <Select value={specialistType} onValueChange={(v) => setSpecialistType(v as SpecialistType)}>
                    <SelectTrigger className="h-11 rounded-xl border-slate-200 bg-white px-4 shadow-sm focus:ring-2 focus:ring-blue-600/20">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="Psychologist">Psychologist</SelectItem>
                      <SelectItem value="Psychiatrist">Psychiatrist</SelectItem>
                      <SelectItem value="Cleric">Cleric</SelectItem>
                      <SelectItem value="Therapist">Therapist</SelectItem>
                    </SelectContent>
                  </Select>
                </div>

                <div className="space-y-2">
                  <Label className="text-sm font-medium text-slate-700">Specialist</Label>
                  <Select value={selectedSpecialistId} onValueChange={setSelectedSpecialistId} disabled={isLoadingSpecialists}>
                    <SelectTrigger className="h-11 rounded-xl border-slate-200 bg-white px-4 shadow-sm focus:ring-2 focus:ring-blue-600/20">
                      <SelectValue placeholder={isLoadingSpecialists ? 'Loading specialists…' : 'Select specialist'} />
                    </SelectTrigger>
                    <SelectContent>
                      {filteredSpecialists.length === 0 && (
                        <SelectItem value="__none" disabled>
                          No specialists found
                        </SelectItem>
                      )}
                      {filteredSpecialists.map((s) => (
                        <SelectItem key={s.id} value={s.id}>
                          {s.name}
                          {s.isAvailable ? '' : ' • unavailable'}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              </div>

              <div className="mt-5 flex flex-col-reverse items-start justify-between gap-3 sm:flex-row sm:items-center">
                <label className="group flex cursor-pointer items-center gap-2 text-sm text-slate-600">
                  <span className="relative inline-flex size-5 items-center justify-center rounded-md border border-slate-200 bg-white shadow-sm transition-colors group-hover:bg-slate-50">
                    <input
                      type="checkbox"
                      className="absolute inset-0 size-full cursor-pointer opacity-0"
                      checked={showOnlyAvailable}
                      onChange={(e) => setShowOnlyAvailable(e.target.checked)}
                    />
                    <span
                      aria-hidden="true"
                      className={cn(
                        'size-2.5 rounded-sm transition-colors',
                        showOnlyAvailable ? 'bg-blue-600' : 'bg-transparent'
                      )}
                    />
                  </span>
                  Only show available specialists
                </label>

                <Button
                  onClick={handleAssign}
                  disabled={!selectedSpecialist || isSubmitting}
                  className="h-11 rounded-xl bg-blue-600 px-5 font-medium text-white shadow-sm hover:bg-blue-700 focus-visible:ring-2 focus-visible:ring-blue-600/20"
                >
                  {isSubmitting ? <Spinner className="mr-2" /> : null}
                  Confirm &amp; Continue
                </Button>
              </div>
            </CardContent>
          </Card>

          {/* SECTION D: Specialist Availability */}
          <Card className="mt-6 border-slate-200 bg-white shadow-sm">
            <CardContent className="p-5 sm:p-6">
              <div className="flex flex-col gap-1 sm:flex-row sm:items-end sm:justify-between">
                <div>
                  <div className="text-base font-semibold text-slate-900">Availability</div>
                  <p className="mt-1 text-sm text-slate-500">Pick a time slot to pre-fill scheduling.</p>
                </div>
              </div>

              {!selectedSpecialist && (
                <div className="mt-4 rounded-xl border border-slate-200 bg-slate-50/60 p-4 text-sm text-slate-600">
                  Assign a specialist to view availability.
                </div>
              )}

              {selectedSpecialist && (
                <div className="mt-4 space-y-4">
                  {groupedSlots.length === 0 && (
                    <div className="rounded-xl border border-slate-200 bg-slate-50/60 p-4 text-sm text-slate-600">
                      No availability slots found.
                    </div>
                  )}

                  {groupedSlots.slice(0, 4).map((group) => (
                    <div key={group.date} className="rounded-xl border border-slate-200 bg-white p-4 shadow-sm">
                      <div className="flex items-center gap-2 text-sm font-semibold text-slate-900">
                        <Calendar className="size-4 text-slate-400" />
                        <span className="truncate">{group.date}</span>
                      </div>
                      <div className="mt-3 flex flex-wrap gap-2">
                        {group.slots.slice(0, 12).map((slot) => {
                          const isSelected = selectedSlot?.date === slot.date && selectedSlot?.time === slot.time
                          return (
                            <button
                              key={`${slot.date}-${slot.time}`}
                              type="button"
                              onClick={() => handlePickSlot({ date: slot.date, time: slot.time })}
                              className={cn(
                                'inline-flex items-center rounded-xl border px-3 py-2 text-sm font-medium shadow-sm transition-all',
                                'focus:outline-none focus-visible:ring-2 focus-visible:ring-blue-600/20',
                                isSelected
                                  ? 'border-blue-500 bg-blue-600 text-white shadow-blue-600/20'
                                  : 'border-slate-200 bg-white text-slate-700 hover:border-blue-200 hover:bg-blue-50'
                              )}
                            >
                              {slot.time}
                            </button>
                          )
                        })}
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>

          {/* SECTION E + F: Schedule + Meeting Link */}
          <Card className="mt-6 border-slate-200 bg-white shadow-sm">
            <CardContent className="p-5 sm:p-6">
              <div>
                <div className="text-base font-semibold text-slate-900">Schedule session</div>
                <p className="mt-1 text-sm text-slate-500">
                  Confirm date, time, and duration, then add or generate a meeting link.
                </p>
              </div>

              <div className="mt-5 grid grid-cols-1 gap-4 sm:grid-cols-3">
                <div className="space-y-2">
                  <Label className="text-sm font-medium text-slate-700">Date</Label>
                  <Input
                    type="date"
                    value={scheduleDate}
                    onChange={(e) => setScheduleDate(e.target.value)}
                    className="h-11 rounded-xl border-slate-200 bg-white shadow-sm focus-visible:ring-2 focus-visible:ring-blue-600/20"
                  />
                </div>
                <div className="space-y-2">
                  <Label className="text-sm font-medium text-slate-700">Time</Label>
                  <Input
                    type="time"
                    value={scheduleTime}
                    onChange={(e) => setScheduleTime(e.target.value)}
                    className="h-11 rounded-xl border-slate-200 bg-white shadow-sm focus-visible:ring-2 focus-visible:ring-blue-600/20"
                  />
                </div>
                <div className="space-y-2">
                  <Label className="text-sm font-medium text-slate-700">Duration (minutes)</Label>
                  <Input
                    type="number"
                    min={15}
                    step={5}
                    value={durationMinutes}
                    onChange={(e) => setDurationMinutes(Number(e.target.value || 45))}
                    className="h-11 rounded-xl border-slate-200 bg-white shadow-sm focus-visible:ring-2 focus-visible:ring-blue-600/20"
                  />
                </div>
              </div>

              <div className="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-3">
                <div className="space-y-2">
                  <Label className="text-sm font-medium text-slate-700">Platform</Label>
                  <Select value={platform} onValueChange={(v) => setPlatform(v as 'zoom' | 'google-meet')}>
                    <SelectTrigger className="h-11 rounded-xl border-slate-200 bg-white px-4 shadow-sm focus:ring-2 focus:ring-blue-600/20">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="google-meet">Google Meet</SelectItem>
                      <SelectItem value="zoom">Zoom</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-2 sm:col-span-2">
                  <Label className="text-sm font-medium text-slate-700">Meeting link</Label>
                  <div className="flex flex-col gap-2 sm:flex-row">
                    <Input
                      value={meetingLink}
                      onChange={(e) => setMeetingLink(e.target.value)}
                      placeholder="https://…"
                      className="h-11 flex-1 rounded-xl border-slate-200 bg-white shadow-sm focus-visible:ring-2 focus-visible:ring-blue-600/20"
                    />
                    <Button
                      type="button"
                      variant="outline"
                      onClick={handleGenerateLink}
                      className="h-11 gap-2 rounded-xl border-slate-200 bg-white hover:bg-slate-50"
                    >
                      <Link2 className="size-4" />
                      Generate
                    </Button>
                  </div>
                </div>
              </div>

              <div className="mt-6 flex flex-col-reverse justify-end gap-2 sm:flex-row">
                <Button
                  variant="outline"
                  onClick={() => setStep('assign')}
                  className="h-11 rounded-xl border-slate-200 bg-white hover:bg-slate-50"
                >
                  Back
                </Button>
                <Button
                  onClick={handleConfirmSchedule}
                  disabled={!canMoveToSchedule || isSubmitting}
                  className="h-11 rounded-xl bg-blue-600 px-5 font-medium text-white shadow-sm hover:bg-blue-700 focus-visible:ring-2 focus-visible:ring-blue-600/20"
                >
                  {isSubmitting ? <Spinner className="mr-2" /> : null}
                  Confirm Schedule
                </Button>
              </div>
            </CardContent>
          </Card>

          {/* SECTION G: Send Instructions */}
          <Card className="mt-6 border-slate-200 bg-white shadow-sm">
            <CardContent className="p-5 sm:p-6">
              <div className="flex items-start justify-between gap-4">
                <div>
                  <div className="text-base font-semibold text-slate-900">Instructions</div>
                  <p className="mt-1 text-sm text-slate-500">
                    Message the client with what to expect {isPhysicalSession ? 'and where to meet.' : 'and how to join.'}
                  </p>
                </div>
              </div>

              <div className="mt-4 space-y-2">
                <Label className="text-sm font-medium text-slate-700">Instructions</Label>
                <Textarea
                  value={instructions}
                  onChange={(e) => setInstructions(e.target.value)}
                  placeholder={[
                    'Hi, your consultation has been scheduled.',
                    '',
                    '- Join 5 minutes early',
                    '- Ensure your microphone/camera work',
                    '- Find a private, quiet space',
                  ].join('\n')}
                  rows={6}
                  className="rounded-xl border-slate-200 bg-white shadow-sm focus-visible:ring-2 focus-visible:ring-blue-600/20"
                />
              </div>

              <div className="mt-4 flex justify-end">
                <Button
                  onClick={handleSendInstructions}
                  disabled={isSubmitting}
                  className="h-11 rounded-xl bg-blue-600 px-5 font-medium text-white shadow-sm hover:bg-blue-700 focus-visible:ring-2 focus-visible:ring-blue-600/20"
                >
                  {isSubmitting ? <Spinner className="mr-2" /> : null}
                  Send to Client
                </Button>
              </div>
            </CardContent>
          </Card>

          {isPhysicalSession && (
            <Card className="mt-6 border-slate-200 bg-white shadow-sm">
              <CardContent className="p-5 sm:p-6">
                <div>
                  <div className="text-base font-semibold text-slate-900">Payment</div>
                  <p className="mt-1 text-sm text-slate-500">Agree amount with client and send payment instructions.</p>
                </div>

                <div className="mt-5 grid grid-cols-1 gap-4 sm:grid-cols-3">
                  <div className="space-y-2 sm:col-span-1">
                    <Label className="text-sm font-medium text-slate-700">Amount agreed</Label>
                    <Input
                      value={paymentAmount}
                      onChange={(e) => setPaymentAmount(e.target.value)}
                      placeholder="e.g. KES 2,000"
                      className="h-11 rounded-xl border-slate-200 bg-white shadow-sm focus-visible:ring-2 focus-visible:ring-emerald-600/20"
                    />
                  </div>
                  <div className="space-y-2 sm:col-span-2">
                    <Label className="text-sm font-medium text-slate-700">Payment instructions</Label>
                    <Input
                      value={paymentInstructions}
                      onChange={(e) => setPaymentInstructions(e.target.value)}
                      placeholder="e.g. Pay via M-Pesa Paybill 123456, Account: <your id>"
                      className="h-11 rounded-xl border-slate-200 bg-white shadow-sm focus-visible:ring-2 focus-visible:ring-emerald-600/20"
                    />
                  </div>
                </div>

                <div className="mt-4 flex flex-wrap justify-end gap-2">
                  <Button
                    type="button"
                    variant="outline"
                    onClick={() => void handleSavePaymentInfo()}
                    disabled={isSubmitting}
                    className="h-11 rounded-xl border-slate-200 bg-white hover:bg-slate-50"
                  >
                    {isSubmitting ? <Spinner className="mr-2" /> : null}
                    Save to notes
                  </Button>
                  <Button
                    type="button"
                    onClick={() => void handleSendPaymentInstructions()}
                    disabled={isSubmitting}
                    className="h-11 rounded-xl bg-emerald-600 px-5 font-medium text-white shadow-sm hover:bg-emerald-700 focus-visible:ring-2 focus-visible:ring-emerald-600/20"
                  >
                    {isSubmitting ? <Spinner className="mr-2" /> : null}
                    Send to client
                  </Button>
                </div>
              </CardContent>
            </Card>
          )}
        </div>
      </SheetContent>
    </Sheet>
  )
}

