'use client'

import { useEffect, useMemo, useState } from 'react'
import Link from 'next/link'
import { MessageSquare, Star } from 'lucide-react'
import { Toaster } from '@/components/ui/sonner'
import { Card, CardContent } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Spinner } from '@/components/ui/spinner'
import { listFeedback, FeedbackApi } from '@/services/feedback'
import { cn } from '@/lib/utils'

function normalizeFeedbackRow(f: FeedbackApi) {
  const sessionId = String(f.session_id || f.consultation_id || '')
  const rating =
    typeof f.rating === 'number'
      ? f.rating
      : typeof (f as any).treatment_rating === 'number'
        ? (f as any).treatment_rating
        : typeof (f as any).app_rating === 'number'
          ? (f as any).app_rating
          : 0
  const comment =
    String(
      f.comment ||
        (f as any).doctor_feedback ||
        (f as any).app_feedback ||
        (f as any).suggestions ||
        ''
    ).trim()
  const createdAt = String(f.created_at || (f as any).date || (f as any).created || '')
  const familyRating = (f as any).family_rating ?? (f as any).familyRating ?? null
  const familyComments = String((f as any).family_comments ?? (f as any).familyComments ?? '').trim()
  return {
    id: String(f.id || sessionId || Math.random()),
    sessionId,
    rating,
    comment,
    createdAt,
    familyRating: typeof familyRating === 'number' ? familyRating : null,
    familyComments,
  }
}

export default function FeedbackPage() {
  const [rows, setRows] = useState<ReturnType<typeof normalizeFeedbackRow>[]>([])
  const [isLoading, setIsLoading] = useState(false)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false
    setIsLoading(true)
    setErrorMessage(null)
    listFeedback()
      .then((data) => {
        if (cancelled) return
        setRows(data.map(normalizeFeedbackRow))
      })
      .catch(() => {
        if (cancelled) return
        setErrorMessage('Failed to load feedback. Is the FastAPI server running at http://localhost:8000?')
      })
      .finally(() => {
        if (cancelled) return
        setIsLoading(false)
      })
    return () => {
      cancelled = true
    }
  }, [])

  const avgRating = useMemo(() => {
    if (rows.length === 0) return 0
    return rows.reduce((acc, r) => acc + (r.rating || 0), 0) / rows.length
  }, [rows])

  return (
    <div className="p-6">
      <Toaster />

      <header className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-xl font-semibold text-foreground">Client Feedback</h1>
          <p className="mt-1 text-sm text-muted-foreground">Review ratings and comments linked to sessions.</p>
        </div>
        <Button asChild variant="outline">
          <Link href="/consultations">Back to Consultations</Link>
        </Button>
      </header>

      <div className="mt-6 grid grid-cols-1 gap-4 sm:grid-cols-3">
        <Card className="border-border sm:col-span-1">
          <CardContent className="p-4">
            <div className="flex items-center gap-2 text-sm font-semibold text-foreground">
              <MessageSquare className="size-4 text-muted-foreground" />
              Total feedback
            </div>
            <div className="mt-2 text-2xl font-bold text-foreground">{rows.length}</div>
          </CardContent>
        </Card>
        <Card className="border-border sm:col-span-2">
          <CardContent className="p-4">
            <div className="flex items-center justify-between">
              <div className="text-sm font-semibold text-foreground">Average rating</div>
              <Badge variant="outline">{avgRating ? avgRating.toFixed(1) : '—'}/5</Badge>
            </div>
            <div className="mt-2 flex items-center gap-1">
              {[1, 2, 3, 4, 5].map((s) => (
                <Star
                  key={s}
                  className={cn('size-4', s <= Math.round(avgRating) ? 'fill-warning text-warning' : 'text-muted-foreground/30')}
                />
              ))}
            </div>
          </CardContent>
        </Card>
      </div>

      {(isLoading || errorMessage) && (
        <div className="mt-4 rounded-xl border border-border bg-card p-4">
          {isLoading && (
            <div className="flex items-center gap-2 text-sm text-muted-foreground">
              <Spinner className="size-4" />
              Loading feedback…
            </div>
          )}
          {errorMessage && <div className="text-sm text-destructive">{errorMessage}</div>}
        </div>
      )}

      <section className="mt-6 space-y-3">
        {rows.length === 0 && !isLoading && !errorMessage && (
          <div className="rounded-xl border border-border bg-card p-8 text-center text-sm text-muted-foreground">
            No feedback submitted yet.
          </div>
        )}

        {rows.map((r) => (
          <Card key={r.id} className="border-border">
            <CardContent className="p-4">
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <div className="text-sm font-semibold text-foreground">Session {r.sessionId ? `#${r.sessionId}` : ''}</div>
                  <div className="mt-1 flex items-center gap-2">
                    <Badge variant="outline">{r.rating}/5</Badge>
                    {r.createdAt && <span className="text-xs text-muted-foreground">{r.createdAt}</span>}
                  </div>
                </div>
                {r.sessionId && (
                  <Button size="sm" variant="outline" asChild>
                    <Link href={`/consultations?open=${encodeURIComponent(r.sessionId)}`}>Open session</Link>
                  </Button>
                )}
              </div>

              {r.comment && (
                <p className="mt-3 whitespace-pre-wrap text-sm text-muted-foreground">{r.comment}</p>
              )}

              {(r.familyRating != null || r.familyComments) && (
                <div className="mt-4 rounded-lg border border-border bg-muted/20 p-3">
                  <div className="text-sm font-semibold text-foreground">Family feedback</div>
                  <div className="mt-1 flex flex-wrap items-center gap-2">
                    {r.familyRating != null && <Badge variant="outline">{r.familyRating}/5</Badge>}
                    {r.familyComments && (
                      <p className="whitespace-pre-wrap text-sm text-muted-foreground">{r.familyComments}</p>
                    )}
                  </div>
                </div>
              )}
            </CardContent>
          </Card>
        ))}
      </section>
    </div>
  )
}

