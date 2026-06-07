'use client'

import { useState } from 'react'
import { Check, Circle } from 'lucide-react'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import { Badge } from '@/components/ui/badge'
import { Specialist, SpecialistType } from '@/lib/data'
import { cn } from '@/lib/utils'

interface AssignSpecialistDialogProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  specialists: Specialist[]
  onAssign: (specialist: Specialist) => void
}

const specialistTypes: SpecialistType[] = ['Psychologist', 'Psychiatrist', 'Cleric', 'Therapist']

export function AssignSpecialistDialog({
  open,
  onOpenChange,
  specialists,
  onAssign,
}: AssignSpecialistDialogProps) {
  const [selectedType, setSelectedType] = useState<SpecialistType | 'all'>('all')
  const [selectedSpecialist, setSelectedSpecialist] = useState<Specialist | null>(null)

  const filteredSpecialists =
    selectedType === 'all'
      ? specialists
      : specialists.filter((s) => s.type === selectedType)

  const getInitials = (name: string) => {
    return name
      .split(' ')
      .map((n) => n[0])
      .join('')
      .toUpperCase()
  }

  const handleAssign = () => {
    if (selectedSpecialist) {
      onAssign(selectedSpecialist)
      setSelectedSpecialist(null)
      setSelectedType('all')
    }
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-lg">
        <DialogHeader>
          <DialogTitle>Assign Specialist</DialogTitle>
          <DialogDescription>
            Select a specialist to assign to this consultation request.
          </DialogDescription>
        </DialogHeader>

        {/* Filter by type */}
        <div className="flex flex-wrap gap-2">
          <Button
            size="sm"
            variant={selectedType === 'all' ? 'default' : 'outline'}
            onClick={() => setSelectedType('all')}
          >
            All
          </Button>
          {specialistTypes.map((type) => (
            <Button
              key={type}
              size="sm"
              variant={selectedType === type ? 'default' : 'outline'}
              onClick={() => setSelectedType(type)}
            >
              {type}
            </Button>
          ))}
        </div>

        {/* Specialists list */}
        <div className="max-h-[300px] space-y-2 overflow-y-auto">
          {filteredSpecialists.map((specialist) => (
            <div
              key={specialist.id}
              className={cn(
                'flex cursor-pointer items-center gap-3 rounded-lg border p-3 transition-colors',
                selectedSpecialist?.id === specialist.id
                  ? 'border-primary bg-primary/5'
                  : 'border-border hover:border-primary/50'
              )}
              onClick={() => setSelectedSpecialist(specialist)}
            >
              <Avatar className="size-10">
                <AvatarImage src={specialist.avatar} alt={specialist.name} />
                <AvatarFallback className="bg-primary/10 text-sm text-primary">
                  {getInitials(specialist.name)}
                </AvatarFallback>
              </Avatar>
              <div className="flex-1">
                <div className="flex items-center gap-2">
                  <p className="text-sm font-medium text-foreground">{specialist.name}</p>
                  <Badge variant="outline" className="text-xs">
                    {specialist.type}
                  </Badge>
                </div>
                <p className="text-xs text-muted-foreground">{specialist.email}</p>
              </div>
              <div className="flex items-center gap-2">
                <div className="flex items-center gap-1 text-xs">
                  <Circle
                    className={cn(
                      'size-2',
                      specialist.isAvailable ? 'fill-success text-success' : 'fill-muted text-muted'
                    )}
                  />
                  <span className={specialist.isAvailable ? 'text-success' : 'text-muted-foreground'}>
                    {specialist.isAvailable ? 'Available' : 'Busy'}
                  </span>
                </div>
                {selectedSpecialist?.id === specialist.id && (
                  <Check className="size-4 text-primary" />
                )}
              </div>
            </div>
          ))}
        </div>

        {/* Availability Preview */}
        {selectedSpecialist && (
          <div className="rounded-lg border border-border bg-muted/50 p-3">
            <p className="mb-2 text-sm font-medium text-foreground">
              {selectedSpecialist.name}&apos;s Availability
            </p>
            <div className="flex flex-wrap gap-2">
              {selectedSpecialist.availability.map((avail) => (
                <div key={avail.day} className="text-xs">
                  <span className="font-medium text-foreground">{avail.day}:</span>{' '}
                  <span className="text-muted-foreground">{avail.slots.join(', ')}</span>
                </div>
              ))}
            </div>
          </div>
        )}

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            Cancel
          </Button>
          <Button onClick={handleAssign} disabled={!selectedSpecialist}>
            Assign Specialist
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
