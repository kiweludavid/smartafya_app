'use client'

import { useEffect, useState } from 'react'
import { Users } from 'lucide-react'
import { Card, CardContent } from '@/components/ui/card'
import { Spinner } from '@/components/ui/spinner'
import { Toaster } from '@/components/ui/sonner'
import { listClients } from '@/services/clients'

export default function ClientsPage() {
  const [clients, setClients] = useState<any[]>([])
  const [isLoading, setIsLoading] = useState(false)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false
    setIsLoading(true)
    setErrorMessage(null)
    listClients()
      .then((data) => {
        if (cancelled) return
        setClients(data)
      })
      .catch(() => {
        if (cancelled) return
        setErrorMessage('Failed to load clients. Is the FastAPI server running at http://localhost:8000?')
      })
      .finally(() => {
        if (cancelled) return
        setIsLoading(false)
      })
    return () => {
      cancelled = true
    }
  }, [])

  return (
    <div className="p-6">
      <Toaster />
      <header>
        <h1 className="text-xl font-semibold text-foreground">Clients</h1>
        <p className="mt-1 text-sm text-muted-foreground">Client directory.</p>
      </header>

      {(isLoading || errorMessage) && (
        <div className="mt-4 rounded-xl border border-border bg-card p-4">
          {isLoading && (
            <div className="flex items-center gap-2 text-sm text-muted-foreground">
              <Spinner className="size-4" />
              Loading clients…
            </div>
          )}
          {errorMessage && <div className="text-sm text-destructive">{errorMessage}</div>}
        </div>
      )}

      <div className="mt-6 grid grid-cols-1 gap-3 md:grid-cols-2">
        {clients.length === 0 && !isLoading && !errorMessage && (
          <div className="rounded-xl border border-border bg-card p-8 text-center text-sm text-muted-foreground">
            No clients found.
          </div>
        )}
        {clients.map((c) => (
          <Card key={String(c.id || c.email || Math.random())} className="border-border">
            <CardContent className="p-4">
              <div className="flex items-start gap-3">
                <div className="flex size-10 items-center justify-center rounded-lg bg-primary/10">
                  <Users className="size-5 text-primary" />
                </div>
                <div className="min-w-0">
                  <div className="truncate text-sm font-semibold text-foreground">{String(c.name || c.full_name || 'Unknown client')}</div>
                  <div className="mt-1 truncate text-xs text-muted-foreground">{String(c.email || '')}</div>
                  <div className="mt-1 truncate text-xs text-muted-foreground">{String(c.phone || '')}</div>
                </div>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  )
}

