'use client'

import { useEffect, useMemo, useState } from 'react'
import Link from 'next/link'
import { FileText } from 'lucide-react'
import { Card, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Spinner } from '@/components/ui/spinner'
import { Toaster } from '@/components/ui/sonner'
import { ConsultationRequest } from '@/lib/data'
import { listConsultations, mapConsultationApiToUi } from '@/services/consultations'

export default function ReportsPage() {
  const [consultations, setConsultations] = useState<ConsultationRequest[]>([])
  const [isLoading, setIsLoading] = useState(false)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false
    setIsLoading(true)
    setErrorMessage(null)
    listConsultations()
      .then((data) => {
        if (cancelled) return
        setConsultations(data.map(mapConsultationApiToUi))
      })
      .catch(() => {
        if (cancelled) return
        setErrorMessage('Failed to load sessions. Is the FastAPI server running at http://localhost:8000?')
      })
      .finally(() => {
        if (cancelled) return
        setIsLoading(false)
      })
    return () => {
      cancelled = true
    }
  }, [])

  const reports = useMemo(() => {
    return consultations
      .filter((c) => Boolean(c.sessionReport))
      .sort((a, b) => new Date(b.requestedDate).getTime() - new Date(a.requestedDate).getTime())
  }, [consultations])

  return (
    <div className="p-6">
      <Toaster />

      <header className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-xl font-semibold text-foreground">Session Reports</h1>
          <p className="mt-1 text-sm text-muted-foreground">Review doctor reports, diagnosis, and recommendations.</p>
        </div>
        <Button asChild variant="outline">
          <Link href="/consultations">Go to Consultations</Link>
        </Button>
      </header>

      {(isLoading || errorMessage) && (
        <div className="mt-4 rounded-xl border border-border bg-card p-4">
          {isLoading && (
            <div className="flex items-center gap-2 text-sm text-muted-foreground">
              <Spinner className="size-4" />
              Loading reports…
            </div>
          )}
          {errorMessage && <div className="text-sm text-destructive">{errorMessage}</div>}
        </div>
      )}

      <section className="mt-6 space-y-3">
        {reports.length === 0 && !isLoading && !errorMessage && (
          <div className="rounded-xl border border-border bg-card p-8 text-center text-sm text-muted-foreground">
            No session reports available yet.
          </div>
        )}

        {reports.map((r) => (
          <Card key={r.id} className="border-border">
            <CardContent className="p-4">
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <div className="flex items-center gap-2 text-sm font-semibold text-foreground">
                    <FileText className="size-4 text-muted-foreground" />
                    Report for {r.client.name}
                  </div>
                  <div className="mt-1 text-xs text-muted-foreground">
                    Specialist: {r.assignedSpecialist?.name || '—'}
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  <Badge variant="outline" className="capitalize">
                    {r.status}
                  </Badge>
                  <Button size="sm" variant="outline" asChild>
                    <Link href={`/consultations?open=${encodeURIComponent(r.id)}`}>View Full Report</Link>
                  </Button>
                </div>
              </div>

              <p className="mt-3 line-clamp-3 whitespace-pre-wrap text-sm text-muted-foreground">{r.sessionReport}</p>
            </CardContent>
          </Card>
        ))}
      </section>
    </div>
  )
}

