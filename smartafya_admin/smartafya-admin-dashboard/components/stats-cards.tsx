'use client'

import { ClipboardList, UserCheck, Calendar, MessageSquare, BadgeDollarSign } from 'lucide-react'
import { Card, CardContent } from '@/components/ui/card'
import { ConsultationRequest } from '@/lib/data'
import { cn } from '@/lib/utils'

interface StatsCardsProps {
  consultations: ConsultationRequest[]
  feedbackCount?: number
  onFeedbackClick?: () => void
}

export function StatsCards({ consultations, feedbackCount, onFeedbackClick }: StatsCardsProps) {
  // Pending = not yet assigned (needs action).
  const pendingCount = consultations.filter((c) => c.status === 'pending').length
  const scheduledCount = consultations.filter((c) => c.status === 'scheduled').length
  // Completed = session conducted (not merely scheduled).
  const completedCount = consultations.filter((c) => c.status === 'completed').length
  const computedFeedbackCount = consultations.filter((c) => c.feedback).length
  const feedbackTotal = typeof feedbackCount === 'number' ? feedbackCount : computedFeedbackCount
  const paymentsToReviewCount = consultations.filter((c) => c.paymentStatus === 'proof_submitted').length

  const stats = [
    {
      label: 'Pending Requests',
      value: pendingCount,
      icon: ClipboardList,
      color: 'text-warning',
      bgColor: 'bg-warning/10',
    },
    {
      label: 'Payments to Review',
      value: paymentsToReviewCount,
      icon: BadgeDollarSign,
      color: 'text-chart-1',
      bgColor: 'bg-chart-1/10',
    },
    {
      label: 'Scheduled Sessions',
      value: scheduledCount,
      icon: Calendar,
      color: 'text-primary',
      bgColor: 'bg-primary/10',
    },
    {
      label: 'Completed Sessions',
      value: completedCount,
      icon: UserCheck,
      color: 'text-success',
      bgColor: 'bg-success/10',
    },
    {
      label: 'Client Feedback',
      value: feedbackTotal,
      icon: MessageSquare,
      color: 'text-chart-2',
      bgColor: 'bg-chart-2/10',
    },
  ]

  return (
    <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
      {stats.map((stat) => (
        <Card
          key={stat.label}
          className={cn('border-border', stat.label === 'Client Feedback' && onFeedbackClick && 'cursor-pointer hover:bg-muted/30 transition-colors')}
          onClick={stat.label === 'Client Feedback' ? onFeedbackClick : undefined}
          role={stat.label === 'Client Feedback' && onFeedbackClick ? 'button' : undefined}
          tabIndex={stat.label === 'Client Feedback' && onFeedbackClick ? 0 : undefined}
          onKeyDown={
            stat.label === 'Client Feedback' && onFeedbackClick
              ? (e) => {
                  if (e.key === 'Enter' || e.key === ' ') onFeedbackClick()
                }
              : undefined
          }
        >
          <CardContent className="flex items-center gap-4 p-4">
            <div className={`flex size-12 items-center justify-center rounded-lg ${stat.bgColor}`}>
              <stat.icon className={`size-6 ${stat.color}`} />
            </div>
            <div>
              <p className="text-2xl font-bold text-foreground">{stat.value}</p>
              <p className="text-sm text-muted-foreground">{stat.label}</p>
            </div>
          </CardContent>
        </Card>
      ))}
    </div>
  )
}
