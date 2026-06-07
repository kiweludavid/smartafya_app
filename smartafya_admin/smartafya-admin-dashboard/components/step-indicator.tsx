'use client'

import { cn } from '@/lib/utils'

export type Step = {
  key: string
  label: string
  description?: string
  isComplete?: boolean
}

export function StepIndicator({
  steps,
  activeKey,
  className,
}: {
  steps: Step[]
  activeKey: string
  className?: string
}) {
  return (
    <ol
      className={cn(
        'grid grid-cols-2 gap-x-3 gap-y-3 sm:grid-cols-4 sm:gap-x-4',
        className
      )}
    >
      {steps.map((s, idx) => {
        const isActive = s.key === activeKey
        const isComplete = Boolean(s.isComplete)
        const isUpcoming = !isActive && !isComplete
        return (
          <li key={s.key} className="relative">
            {/* Connector line (desktop) */}
            {idx < steps.length - 1 && (
              <div
                aria-hidden="true"
                className={cn(
                  'pointer-events-none absolute left-[14px] top-3 hidden h-[2px] w-[calc(100%-28px)] sm:block',
                  isComplete ? 'bg-emerald-500/60' : 'bg-slate-200'
                )}
              />
            )}

            <div
              className={cn(
                'flex items-start gap-3 rounded-xl border bg-white px-3 py-3 shadow-sm transition-colors',
                isActive && 'border-blue-200 ring-2 ring-blue-600/10',
                isComplete && !isActive && 'border-emerald-200',
                isUpcoming && 'border-slate-200'
              )}
            >
              <div
                className={cn(
                  'relative z-10 flex size-7 shrink-0 items-center justify-center rounded-full border text-xs font-semibold',
                  isComplete
                    ? 'border-emerald-200 bg-emerald-500 text-white'
                    : isActive
                      ? 'border-blue-200 bg-blue-600 text-white'
                      : 'border-slate-200 bg-slate-50 text-slate-500'
                )}
              >
                {idx + 1}
              </div>

              <div className="min-w-0">
                <div className={cn('text-xs font-semibold leading-4', isActive ? 'text-slate-900' : 'text-slate-700')}>
                  {s.label}
                </div>
                {s.description && (
                  <div className="mt-0.5 truncate text-[11px] leading-4 text-slate-500">{s.description}</div>
                )}
              </div>
            </div>
          </li>
        )
      })}
    </ol>
  )
}

