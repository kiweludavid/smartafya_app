'use client'

import { useEffect, useMemo, useState } from 'react'
import { UserCheck } from 'lucide-react'
import { Card, CardContent } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Spinner } from '@/components/ui/spinner'
import { Toaster } from '@/components/ui/sonner'
import { listSpecialists } from '@/services/specialists'
import { safeAvatarUrl, SpecialistType } from '@/lib/data'

function specialistTypeToUi(t: string | null | undefined): SpecialistType {
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

export default function SpecialistsPage() {
  const [rows, setRows] = useState<any[]>([])
  const [isLoading, setIsLoading] = useState(false)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false
    setIsLoading(true)
    setErrorMessage(null)
    listSpecialists()
      .then((data) => {
        if (cancelled) return
        setRows(data)
      })
      .catch(() => {
        if (cancelled) return
        setErrorMessage('Failed to load specialists. Is the FastAPI server running at http://localhost:8000?')
      })
      .finally(() => {
        if (cancelled) return
        setIsLoading(false)
      })
    return () => {
      cancelled = true
    }
  }, [])

  const normalized = useMemo(() => {
    return rows.map((r) => {
      const name = String(r?.name || r?.full_name || 'Unknown specialist')
      return {
        id: String(r?.id || name),
        name,
        email: String(r?.email || ''),
        phone: String(r?.phone || ''),
        type: specialistTypeToUi(r?.type || r?.specialist_type),
        isAvailable: r?.is_available == null ? true : Boolean(r.is_available),
        avatar: safeAvatarUrl(name),
      }
    })
  }, [rows])

  return (
    <div className="p-6">
      <Toaster />
      <header>
        <h1 className="text-xl font-semibold text-foreground">Specialists</h1>
        <p className="mt-1 text-sm text-muted-foreground">Specialist directory and availability flags.</p>
      </header>

      {(isLoading || errorMessage) && (
        <div className="mt-4 rounded-xl border border-border bg-card p-4">
          {isLoading && (
            <div className="flex items-center gap-2 text-sm text-muted-foreground">
              <Spinner className="size-4" />
              Loading specialists…
            </div>
          )}
          {errorMessage && <div className="text-sm text-destructive">{errorMessage}</div>}
        </div>
      )}

      <div className="mt-6 grid grid-cols-1 gap-3 md:grid-cols-2">
        {normalized.length === 0 && !isLoading && !errorMessage && (
          <div className="rounded-xl border border-border bg-card p-8 text-center text-sm text-muted-foreground">
            No specialists found.
          </div>
        )}

        {normalized.map((s) => (
          <Card key={s.id} className="border-border">
            <CardContent className="p-4">
              <div className="flex items-start justify-between gap-3">
                <div className="flex min-w-0 items-start gap-3">
                  <div className="flex size-10 items-center justify-center rounded-lg bg-primary/10">
                    <UserCheck className="size-5 text-primary" />
                  </div>
                  <div className="min-w-0">
                    <div className="truncate text-sm font-semibold text-foreground">{s.name}</div>
                    <div className="mt-1 flex flex-wrap items-center gap-2">
                      <Badge variant="outline">{s.type}</Badge>
                      <Badge variant="outline">{s.isAvailable ? 'Available' : 'Unavailable'}</Badge>
                    </div>
                    {(s.email || s.phone) && (
                      <div className="mt-2 text-xs text-muted-foreground">
                        {s.email ? <div className="truncate">{s.email}</div> : null}
                        {s.phone ? <div className="truncate">{s.phone}</div> : null}
                      </div>
                    )}
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  )
}

