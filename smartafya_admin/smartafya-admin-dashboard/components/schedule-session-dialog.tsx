'use client'

import { useState } from 'react'
import { Calendar, Video } from 'lucide-react'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { Checkbox } from '@/components/ui/checkbox'
import { ConsultationRequest, Specialist } from '@/lib/data'
import { cn } from '@/lib/utils'

interface ScheduleSessionDialogProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  consultation: ConsultationRequest | null
  onSchedule: (data: {
    date: string
    time: string
    platform: 'zoom' | 'google-meet'
    generateLink: boolean
    sendInstructions: boolean
  }) => void
}

const timeSlots = [
  '09:00', '09:30', '10:00', '10:30', '11:00', '11:30',
  '12:00', '12:30', '13:00', '13:30', '14:00', '14:30',
  '15:00', '15:30', '16:00', '16:30', '17:00'
]

export function ScheduleSessionDialog({
  open,
  onOpenChange,
  consultation,
  onSchedule,
}: ScheduleSessionDialogProps) {
  const [date, setDate] = useState('')
  const [time, setTime] = useState('')
  const [platform, setPlatform] = useState<'zoom' | 'google-meet'>('zoom')
  const [generateLink, setGenerateLink] = useState(true)
  const [sendInstructions, setSendInstructions] = useState(true)

  const handleSchedule = () => {
    onSchedule({
      date,
      time,
      platform,
      generateLink,
      sendInstructions,
    })
    // Reset form
    setDate('')
    setTime('')
    setPlatform('zoom')
    setGenerateLink(true)
    setSendInstructions(true)
  }

  const getAvailableSlots = () => {
    if (!consultation?.assignedSpecialist) return timeSlots

    const specialist = consultation.assignedSpecialist as Specialist
    if (!specialist.availability || specialist.availability.length === 0) return timeSlots
    const selectedDate = new Date(date)
    const dayName = selectedDate.toLocaleDateString('en-US', { weekday: 'long' })
    const dayAvailability = specialist.availability.find((a) => a.day === dayName)

    return dayAvailability ? dayAvailability.slots : []
  }

  const availableSlots = date ? getAvailableSlots() : timeSlots

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <Calendar className="size-5" />
            Schedule Session
          </DialogTitle>
          <DialogDescription>
            {consultation?.assignedSpecialist
              ? `Schedule a session with ${consultation.assignedSpecialist.name}`
              : 'Schedule a consultation session'}
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-4">
          {/* Date Selection */}
          <div className="space-y-2">
            <Label htmlFor="date">Date</Label>
            <Input
              id="date"
              type="date"
              value={date}
              onChange={(e) => {
                setDate(e.target.value)
                setTime('') // Reset time when date changes
              }}
              min={new Date().toISOString().split('T')[0]}
            />
          </div>

          {/* Time Selection */}
          <div className="space-y-2">
            <Label htmlFor="time">Time</Label>
            <Select value={time} onValueChange={setTime}>
              <SelectTrigger>
                <SelectValue placeholder="Select time slot" />
              </SelectTrigger>
              <SelectContent>
                {availableSlots.length > 0 ? (
                  availableSlots.map((slot) => (
                    <SelectItem key={slot} value={slot}>
                      {slot}
                    </SelectItem>
                  ))
                ) : (
                  <SelectItem value="none" disabled>
                    No slots available for this date
                  </SelectItem>
                )}
              </SelectContent>
            </Select>
            {date && availableSlots.length === 0 && (
              <p className="text-xs text-destructive">
                Specialist is not available on this day
              </p>
            )}
          </div>

          {/* Platform Selection */}
          <div className="space-y-2">
            <Label>Meeting Platform</Label>
            <div className="flex gap-2">
              <Button
                type="button"
                variant={platform === 'zoom' ? 'default' : 'outline'}
                size="sm"
                onClick={() => setPlatform('zoom')}
                className="flex-1 gap-2"
              >
                <Video className="size-4" />
                Zoom
              </Button>
              <Button
                type="button"
                variant={platform === 'google-meet' ? 'default' : 'outline'}
                size="sm"
                onClick={() => setPlatform('google-meet')}
                className="flex-1 gap-2"
              >
                <Video className="size-4" />
                Google Meet
              </Button>
            </div>
          </div>

          {/* Options */}
          <div className="space-y-3 rounded-lg border border-border p-3">
            <div className="flex items-center gap-2">
              <Checkbox
                id="generateLink"
                checked={generateLink}
                onCheckedChange={(checked) => setGenerateLink(checked as boolean)}
              />
              <Label htmlFor="generateLink" className="cursor-pointer text-sm">
                Auto-generate meeting link
              </Label>
            </div>
            <div className="flex items-center gap-2">
              <Checkbox
                id="sendInstructions"
                checked={sendInstructions}
                onCheckedChange={(checked) => setSendInstructions(checked as boolean)}
              />
              <Label htmlFor="sendInstructions" className="cursor-pointer text-sm">
                Send session instructions to client
              </Label>
            </div>
          </div>

          {/* Summary */}
          {date && time && (
            <div className="rounded-lg bg-muted/50 p-3">
              <p className="text-sm font-medium text-foreground">Session Summary</p>
              <p className="mt-1 text-sm text-muted-foreground">
                {new Date(date).toLocaleDateString('en-US', {
                  weekday: 'long',
                  year: 'numeric',
                  month: 'long',
                  day: 'numeric',
                })}{' '}
                at {time}
              </p>
              <p className="text-sm text-muted-foreground">
                Platform: {platform === 'zoom' ? 'Zoom' : 'Google Meet'}
              </p>
            </div>
          )}
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            Cancel
          </Button>
          <Button onClick={handleSchedule} disabled={!date || !time}>
            Schedule Session
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
