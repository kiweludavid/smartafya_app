'use client'

import { X, Mail, Phone, MessageSquare, Video, Calendar, Star, FileText, Link2 } from 'lucide-react'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { ConsultationRequest, getStatusColor, formatDate } from '@/lib/data'
import { cn } from '@/lib/utils'

interface ConsultationDetailProps {
  consultation: ConsultationRequest
  onClose: () => void
  onAssign: () => void
  onSchedule: () => void
  onGenerateLink: () => void
  onSendInstructions: () => void
}

export function ConsultationDetail({
  consultation,
  onClose,
  onAssign,
  onSchedule,
  onGenerateLink,
  onSendInstructions,
}: ConsultationDetailProps) {
  const getInitials = (name: string) => {
    return name
      .split(' ')
      .map((n) => n[0])
      .join('')
      .toUpperCase()
  }

  return (
    <div className="fixed right-0 top-0 z-50 h-screen w-[400px] border-l border-border bg-card shadow-lg">
      {/* Header */}
      <div className="flex items-center justify-between border-b border-border px-6 py-4">
        <div className="flex items-center gap-3">
          <span className="text-lg font-semibold text-foreground">Request #{consultation.id}</span>
          <Badge variant="outline" className={cn('capitalize', getStatusColor(consultation.status))}>
            {consultation.status}
          </Badge>
        </div>
        <Button variant="ghost" size="sm" className="size-8 p-0" onClick={onClose}>
          <X className="size-4" />
          <span className="sr-only">Close</span>
        </Button>
      </div>

      <div className="h-[calc(100vh-65px)] overflow-y-auto">
        {/* Client Info */}
        <div className="border-b border-border p-6">
          <div className="mb-4 flex flex-col items-center">
            <Avatar className="mb-3 size-20">
              <AvatarImage src={consultation.client.avatar} alt={consultation.client.name} />
              <AvatarFallback className="bg-primary/10 text-xl text-primary">
                {getInitials(consultation.client.name)}
              </AvatarFallback>
            </Avatar>
            <h3 className="text-lg font-semibold text-foreground">{consultation.client.name}</h3>
            <p className="text-sm text-muted-foreground">Client ID: {consultation.client.id}</p>
          </div>

          <div className="flex justify-center gap-2">
            <Button variant="outline" size="sm" className="gap-2">
              <Mail className="size-4" />
              Email
            </Button>
            <Button variant="outline" size="sm" className="gap-2">
              <Phone className="size-4" />
              Call
            </Button>
            <Button variant="outline" size="sm" className="gap-2">
              <MessageSquare className="size-4" />
              Message
            </Button>
          </div>
        </div>

        {/* Challenge Description */}
        <div className="border-b border-border p-6">
          <h4 className="mb-3 text-sm font-semibold text-foreground">Challenge Description</h4>
          <p className="text-sm leading-relaxed text-muted-foreground">
            {consultation.challengeDescription}
          </p>
          <p className="mt-3 text-xs text-muted-foreground">
            Requested on {formatDate(consultation.requestedDate)}
          </p>
        </div>

        {/* Assigned Specialist */}
        {consultation.assignedSpecialist ? (
          <div className="border-b border-border p-6">
            <h4 className="mb-3 text-sm font-semibold text-foreground">Assigned Specialist</h4>
            <div className="flex items-center gap-3">
              <Avatar className="size-10">
                <AvatarImage
                  src={consultation.assignedSpecialist.avatar}
                  alt={consultation.assignedSpecialist.name}
                />
                <AvatarFallback className="bg-primary/10 text-sm text-primary">
                  {getInitials(consultation.assignedSpecialist.name)}
                </AvatarFallback>
              </Avatar>
              <div>
                <p className="text-sm font-medium text-foreground">
                  {consultation.assignedSpecialist.name}
                </p>
                <p className="text-xs text-muted-foreground">
                  {consultation.assignedSpecialist.type}
                </p>
              </div>
            </div>
          </div>
        ) : (
          <div className="border-b border-border p-6">
            <h4 className="mb-3 text-sm font-semibold text-foreground">Assigned Specialist</h4>
            <p className="mb-3 text-sm text-muted-foreground">No specialist assigned yet</p>
            <Button size="sm" onClick={onAssign} className="gap-2">
              Assign Specialist
            </Button>
          </div>
        )}

        {/* Session Details */}
        {consultation.scheduledDate && (
          <div className="border-b border-border p-6">
            <h4 className="mb-3 text-sm font-semibold text-foreground">Session Details</h4>
            <div className="space-y-3">
              <div className="flex items-center gap-3 text-sm">
                <Calendar className="size-4 text-muted-foreground" />
                <span className="text-foreground">
                  {formatDate(consultation.scheduledDate)} at {consultation.scheduledTime}
                </span>
              </div>
              {consultation.meetingLink && (
                <div className="flex items-center gap-3 text-sm">
                  <Video className="size-4 text-muted-foreground" />
                  <a
                    href={consultation.meetingLink}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-primary hover:underline"
                  >
                    {consultation.meetingPlatform === 'zoom' ? 'Zoom Meeting' : 'Google Meet'}
                  </a>
                </div>
              )}
            </div>
          </div>
        )}

        {/* Session Report */}
        {consultation.sessionReport && (
          <div className="border-b border-border p-6">
            <h4 className="mb-3 flex items-center gap-2 text-sm font-semibold text-foreground">
              <FileText className="size-4" />
              Session Report
            </h4>
            <p className="text-sm leading-relaxed text-muted-foreground">
              {consultation.sessionReport}
            </p>
          </div>
        )}

        {/* Client Feedback */}
        {consultation.feedback && (
          <div className="border-b border-border p-6">
            <h4 className="mb-3 text-sm font-semibold text-foreground">Client Feedback</h4>
            <div className="mb-2 flex items-center gap-1">
              {[1, 2, 3, 4, 5].map((star) => (
                <Star
                  key={star}
                  className={cn(
                    'size-4',
                    star <= consultation.feedback!.rating
                      ? 'fill-warning text-warning'
                      : 'text-muted-foreground/30'
                  )}
                />
              ))}
              <span className="ml-2 text-sm text-muted-foreground">
                {consultation.feedback.rating}/5
              </span>
            </div>
            <p className="text-sm text-muted-foreground">{consultation.feedback.comment}</p>
            <p className="mt-2 text-xs text-muted-foreground">
              Submitted on {formatDate(consultation.feedback.date)}
            </p>
          </div>
        )}

        {/* Actions */}
        <div className="p-6">
          <h4 className="mb-3 text-sm font-semibold text-foreground">Actions</h4>
          <div className="flex flex-wrap gap-2">
            {consultation.status === 'pending' && consultation.consentGiven !== false && (
              <Button size="sm" onClick={onAssign} className="gap-2">
                Assign Specialist
              </Button>
            )}
            {(consultation.status === 'pending' || consultation.status === 'scheduled') && (
              <Button size="sm" variant="outline" onClick={onSchedule} className="gap-2">
                <Calendar className="size-4" />
                Schedule Session
              </Button>
            )}
            {consultation.assignedSpecialist && !consultation.meetingLink && (
              <Button size="sm" variant="outline" onClick={onGenerateLink} className="gap-2">
                <Link2 className="size-4" />
                Generate Meeting Link
              </Button>
            )}
            {consultation.meetingLink && consultation.status !== 'completed' && (
              <Button size="sm" variant="outline" onClick={onSendInstructions} className="gap-2">
                <Mail className="size-4" />
                Send Instructions
              </Button>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}
