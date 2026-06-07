'use client'

import { useEffect, useMemo, useRef, useState } from 'react'
import { useRouter } from 'next/navigation'
import { Filter, Search } from 'lucide-react'
import { ConsultationTable } from '@/components/consultation-table'
import { ConsultationWorkflowSheet } from '@/components/consultation-workflow-sheet'
import { StatsCards } from '@/components/stats-cards'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Spinner } from '@/components/ui/spinner'
import { Toaster } from '@/components/ui/sonner'
import { toast } from 'sonner'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { ConsultationRequest, ConsultationStatus } from '@/lib/data'
import { listConsultations, mapConsultationApiToUi } from '@/services/consultations'
import { listFeedback } from '@/services/feedback'
import { getAdminSessionManagementSummary } from '@/services/care-actions'

export default function ConsultationsPage() {
  const router = useRouter()
  const didAutoOpen = useRef(false)
  const [consultations, setConsultations] = useState<ConsultationRequest[]>([])
  const [feedbackCount, setFeedbackCount] = useState<number | null>(null)
  const [pendingTransferBySessionId, setPendingTransferBySessionId] = useState<Record<string, any>>({})
  const [isLoading, setIsLoading] = useState(false)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  const [searchQuery, setSearchQuery] = useState('')
  const [statusFilter, setStatusFilter] = useState<ConsultationStatus | 'all'>('all')
  const [sortBy, setSortBy] = useState<'date' | 'status'>('date')

  const [detailOpen, setDetailOpen] = useState(false)
  const [activeConsultation, setActiveConsultation] = useState<ConsultationRequest | null>(null)

  const refresh = () => {
    setIsLoading(true)
    setErrorMessage(null)
    return Promise.all([
      listConsultations(),
      listFeedback().catch(() => null),
      getAdminSessionManagementSummary().catch(() => null),
    ])
      .then(([consultationsApi, feedbackApi, summary]) => {
        setConsultations(consultationsApi.map(mapConsultationApiToUi))
        setFeedbackCount(feedbackApi ? feedbackApi.length : null)
        if (summary?.pending_transfer_requests) {
          const map: Record<string, any> = {}
          for (const r of summary.pending_transfer_requests) map[String(r.session_id)] = r
          setPendingTransferBySessionId(map)
        } else {
          setPendingTransferBySessionId({})
        }
      })
      .catch(() => {
        setErrorMessage('Failed to load consultations. Is the FastAPI server running at http://localhost:8000?')
        toast.error('Failed to load consultations')
      })
      .finally(() => setIsLoading(false))
  }

  useEffect(() => {
    let cancelled = false
    void refresh().then(() => {
      if (cancelled) setConsultations([])
    })
    return () => {
      cancelled = true
    }
  }, [])

  useEffect(() => {
    if (typeof window === 'undefined') return
    const id = new URLSearchParams(window.location.search).get('open')
    if (!id) return
    if (didAutoOpen.current) return
    const found = consultations.find((c) => c.id === id) ?? null
    if (!found) return
    setActiveConsultation(found)
    setDetailOpen(true)
    didAutoOpen.current = true
  }, [consultations])

  const filteredConsultations = useMemo(() => {
    let result = [...consultations]
    if (searchQuery) {
      const q = searchQuery.toLowerCase()
      result = result.filter((c) => c.id.toLowerCase().includes(q) || c.client.name.toLowerCase().includes(q))
    }
    if (statusFilter !== 'all') {
      result = result.filter((c) => c.status === statusFilter)
    } else {
      // Default table view focuses on unscheduled requests.
      result = result.filter((c) => c.status === 'pending' || c.status === 'assigned')
    }
    result.sort((a, b) => {
      if (sortBy === 'date') return new Date(b.requestedDate).getTime() - new Date(a.requestedDate).getTime()
      return a.status.localeCompare(b.status)
    })
    return result
  }, [consultations, searchQuery, statusFilter, sortBy])

  const handleViewDetails = (c: ConsultationRequest) => {
    setActiveConsultation(c)
    setDetailOpen(true)
  }

  const handleUpdateConsultation = (next: ConsultationRequest) => {
    setConsultations((prev) => prev.map((c) => (c.id === next.id ? next : c)))
    setActiveConsultation(next)
    // Pull fresh server state so list shows authoritative status/specialist.
    void refresh()
  }

  return (
    <div className="p-6">
      <Toaster />

      <header className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-xl font-semibold text-foreground">Consultations</h1>
          <p className="mt-1 text-sm text-muted-foreground">Workflow-driven management: assign → pick time → schedule → send instructions.</p>
        </div>
      </header>

      <div className="mt-6">
        <StatsCards
          consultations={consultations}
          feedbackCount={feedbackCount ?? undefined}
          onFeedbackClick={() => router.push('/feedback')}
        />
      </div>

      {(isLoading || errorMessage) && (
        <div className="mt-4 rounded-xl border border-border bg-card p-4">
          {isLoading && (
            <div className="flex items-center gap-2 text-sm text-muted-foreground">
              <Spinner className="size-4" />
              Loading consultations…
            </div>
          )}
          {errorMessage && <div className="text-sm text-destructive">{errorMessage}</div>}
        </div>
      )}

      <div className="mt-6 flex flex-wrap items-center gap-3">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            placeholder="Search by request id or client..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-80 pl-9"
          />
        </div>

        <Select value={statusFilter} onValueChange={(v) => setStatusFilter(v as ConsultationStatus | 'all')}>
          <SelectTrigger className="w-44">
            <Filter className="mr-2 size-4" />
            <SelectValue placeholder="Any status" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">Any status</SelectItem>
            <SelectItem value="pending">Pending</SelectItem>
            <SelectItem value="assigned">Assigned</SelectItem>
            <SelectItem value="scheduled">Scheduled</SelectItem>
            <SelectItem value="completed">Completed</SelectItem>
          </SelectContent>
        </Select>

        <Select value={sortBy} onValueChange={(v) => setSortBy(v as 'date' | 'status')}>
          <SelectTrigger className="w-44">
            <SelectValue placeholder="Sort by" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="date">Sort by Date</SelectItem>
            <SelectItem value="status">Sort by Status</SelectItem>
          </SelectContent>
        </Select>

        <div className="ml-auto">
          <Button variant="outline" onClick={() => void refresh()}>
            Refresh
          </Button>
        </div>
      </div>

      <div className="mt-4">
        <ConsultationTable consultations={filteredConsultations} onViewDetails={handleViewDetails} />
      </div>

      <ConsultationWorkflowSheet
        open={detailOpen}
        onOpenChange={setDetailOpen}
        consultation={activeConsultation}
        onUpdate={handleUpdateConsultation}
        pendingTransferRequest={activeConsultation ? pendingTransferBySessionId[String(activeConsultation.id)] ?? null : null}
      />
    </div>
  )
}

