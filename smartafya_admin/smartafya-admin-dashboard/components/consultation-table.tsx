'use client'

import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { ConsultationRequest, getStatusColor, formatDate } from '@/lib/data'
import { cn } from '@/lib/utils'

interface ConsultationTableProps {
  consultations: ConsultationRequest[]
  onViewDetails: (consultation: ConsultationRequest) => void
}

export function ConsultationTable({
  consultations,
  onViewDetails,
}: ConsultationTableProps) {
  const getInitials = (name: string) => {
    return name
      .split(' ')
      .map((n) => n[0])
      .join('')
      .toUpperCase()
  }

  const rowGrid =
    'grid w-full min-w-0 grid-cols-[minmax(0,5.5rem)_minmax(0,1fr)_minmax(0,6.5rem)_minmax(0,8.5rem)_minmax(0,4.5rem)_8.75rem] items-start gap-x-3 gap-y-1 sm:gap-x-4'

  return (
    <div className="overflow-x-auto rounded-lg border border-border bg-card">
      {/* Table Header */}
      <div
        className={cn(
          rowGrid,
          'border-b border-border px-3 py-3 text-sm font-medium text-muted-foreground sm:px-4'
        )}
      >
        <div className="min-w-0">Request ID</div>
        <div className="min-w-0 text-sm leading-snug">
          <span className="block font-medium text-foreground">Client</span>
          <span className="block text-xs font-normal text-muted-foreground">Challenge</span>
        </div>
        <div className="min-w-0">Status</div>
        <div className="min-w-0">Specialist</div>
        <div className="min-w-0">Date</div>
        <div className="flex min-w-0 justify-end text-right">Action</div>
      </div>

      {/* Table Body */}
      <div className="divide-y divide-border">
        {consultations.map((consultation) => (
          <div
            key={consultation.id}
            className={cn(rowGrid, 'px-3 py-3 transition-colors hover:bg-muted/50 sm:px-4')}
          >
            <div
              className="min-w-0 pt-0.5 font-mono text-xs font-medium leading-tight text-foreground"
              title={`#${consultation.id}`}
            >
              <span className="block truncate">#{consultation.id}</span>
            </div>
            <div className="flex min-w-0 items-start gap-3">
              <Avatar className="size-8 shrink-0">
                <AvatarImage src={consultation.client.avatar} alt={consultation.client.name} />
                <AvatarFallback className="bg-primary/10 text-xs text-primary">
                  {getInitials(consultation.client.name)}
                </AvatarFallback>
              </Avatar>
              <div className="flex min-w-0 flex-1 flex-col gap-1">
                <span
                  className="truncate text-sm font-bold leading-tight text-foreground"
                  title={consultation.client.name}
                >
                  {consultation.client.name}
                </span>
                <p
                  className="challenge-description line-clamp-3 text-xs leading-relaxed text-muted-foreground"
                  title={consultation.challengeDescription}
                >
                  {consultation.challengeDescription}
                </p>
              </div>
            </div>
            <div className="min-w-0 pt-0.5">
              <div className="flex flex-col gap-1">
                <Badge
                  variant="outline"
                  className={cn('max-w-full truncate capitalize', getStatusColor(consultation.status))}
                >
                  {consultation.status}
                </Badge>
                {consultation.paymentStatus === 'proof_submitted' && (
                  <Badge variant="outline" className="max-w-full truncate border-chart-1/30 bg-chart-1/10 text-chart-1">
                    Payment proof submitted
                  </Badge>
                )}
              </div>
            </div>
            <div className="min-w-0 pt-0.5 text-sm text-muted-foreground">
              <span className="line-clamp-2 break-words">
                {consultation.assignedSpecialist
                  ? consultation.assignedSpecialist.name.split(' ').slice(0, 2).join(' ')
                  : '—'}
              </span>
            </div>
            <div className="min-w-0 whitespace-nowrap pt-0.5 text-sm text-muted-foreground">
              {formatDate(consultation.requestedDate)}
            </div>
            <div className="flex min-w-0 items-center justify-end self-stretch">
              <Button size="sm" variant="outline" className="shrink-0" onClick={() => onViewDetails(consultation)}>
                View Details
              </Button>
            </div>
          </div>
        ))}
      </div>

      {consultations.length === 0 && (
        <div className="flex h-32 items-center justify-center text-sm text-muted-foreground">
          No consultation requests found
        </div>
      )}
    </div>
  )
}
