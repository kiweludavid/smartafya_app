'use client'

import { useEffect, useMemo, useState } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { ArrowRight } from 'lucide-react'
import { StatsCards } from '@/components/stats-cards'
import { ConsultationTable } from '@/components/consultation-table'
import { Button } from '@/components/ui/button'
import { Spinner } from '@/components/ui/spinner'
import { Toaster } from '@/components/ui/sonner'
import { toast } from 'sonner'
import { ConsultationRequest } from '@/lib/data'
import { listConsultations, mapConsultationApiToUi } from '@/services/consultations'
import { listFeedback } from '@/services/feedback'

export default function DashboardPage() {
  const router = useRouter()
  const [consultations, setConsultations] = useState<ConsultationRequest[]>([])
  const [feedbackCount, setFeedbackCount] = useState<number | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false
    setIsLoading(true)
    setErrorMessage(null)
    Promise.all([listConsultations(), listFeedback().catch(() => null)])
      .then(([consultationsApi, feedbackApi]) => {
        if (cancelled) return
        setConsultations(consultationsApi.map(mapConsultationApiToUi))
        setFeedbackCount(feedbackApi ? feedbackApi.length : null)
      })
      .catch(() => {
        if (cancelled) return
        setErrorMessage('Failed to load dashboard data. Is the FastAPI server running at http://localhost:8000?')
        toast.error('Failed to load dashboard data')
      })
      .finally(() => {
        if (cancelled) return
        setIsLoading(false)
      })
    return () => {
      cancelled = true
    }
  }, [])

  const recentConsultations = useMemo(() => {
    // Keep the dashboard focused on requests that still need scheduling.
    return [...consultations]
      .filter((c) => c.status === 'pending' || c.status === 'assigned')
      .sort((a, b) => new Date(b.requestedDate).getTime() - new Date(a.requestedDate).getTime())
      .slice(0, 6)
  }, [consultations])

  return (
    <div className="p-6">
      <Toaster />

      <header className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-xl font-semibold text-foreground">Dashboard</h1>
          <p className="mt-1 text-sm text-muted-foreground">High-level overview. Manage requests from the Consultations workflow.</p>
        </div>
        <Button asChild>
          <Link href="/consultations" className="gap-2">
            Go to Consultations <ArrowRight className="size-4" />
          </Link>
        </Button>
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
              Loading dashboard…
            </div>
          )}
          {errorMessage && <div className="text-sm text-destructive">{errorMessage}</div>}
        </div>
      )}

      <section className="mt-8">
        <div className="mb-3 flex items-center justify-between">
          <h2 className="text-sm font-semibold text-foreground">Recent consultation requests</h2>
          <Button variant="outline" size="sm" asChild>
            <Link href="/consultations">View all</Link>
          </Button>
        </div>

        <ConsultationTable
          consultations={recentConsultations}
          onViewDetails={(c) => router.push(`/consultations?open=${encodeURIComponent(c.id)}`)}
        />
      </section>
    </div>
  )
}

