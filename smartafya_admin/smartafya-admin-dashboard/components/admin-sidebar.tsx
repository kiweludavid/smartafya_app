'use client'

import { cn } from '@/lib/utils'
import Link from 'next/link'
import Image from 'next/image'
import { usePathname, useRouter } from 'next/navigation'
import { clearAuthToken } from '@/lib/auth-storage'
import { Button } from '@/components/ui/button'
import {
  LayoutDashboard,
  ClipboardList,
  Users,
  UserCheck,
  FileText,
  MessageSquare,
} from 'lucide-react'

interface NavItem {
  icon: React.ComponentType<{ className?: string }>
  label: string
  href: string
  badge?: number
}

const navItems: NavItem[] = [
  { icon: LayoutDashboard, label: 'Dashboard', href: '/' },
  { icon: ClipboardList, label: 'Consultations', href: '/consultations' },
  { icon: Users, label: 'Clients', href: '/clients' },
  { icon: UserCheck, label: 'Specialists', href: '/specialists' },
  { icon: FileText, label: 'Reports', href: '/reports' },
  { icon: MessageSquare, label: 'Feedback', href: '/feedback' },
]

export function AdminSidebar() {
  const pathname = usePathname()
  const router = useRouter()
  return (
    <aside className="fixed left-0 top-0 z-40 h-screen w-[220px] border-r border-sidebar-border bg-sidebar">
      <div className="flex h-full flex-col">
        {/* Logo */}
        <div className="flex h-16 items-center gap-2 border-b border-sidebar-border px-4">
          <div className="flex size-10 items-center justify-center overflow-hidden rounded-full border border-sidebar-border bg-white shadow-sm">
            <Image
              src="/smartafya-logo.png"
              alt="Smart Afya Solutions"
              width={40}
              height={40}
              className="size-10 object-cover"
              priority
            />
          </div>
          <span className="text-lg font-semibold text-sidebar-foreground">Smart Afya</span>
        </div>

        {/* Navigation */}
        <nav className="flex-1 space-y-1 overflow-y-auto px-3 py-4">
          {navItems.map((item) => {
            const isActive = pathname === item.href || (item.href !== '/' && pathname?.startsWith(item.href))
            return (
              <Link
                key={item.label}
                href={item.href}
                className={cn(
                  'flex w-full items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors',
                  isActive
                    ? 'bg-sidebar-accent text-sidebar-accent-foreground'
                    : 'text-sidebar-foreground/70 hover:bg-sidebar-accent/50 hover:text-sidebar-foreground'
                )}
              >
                <item.icon className={cn('size-5', isActive && 'text-primary')} />
                <span className="flex-1 text-left">{item.label}</span>
                {item.badge && (
                  <span className="flex size-5 items-center justify-center rounded-full bg-primary text-xs text-primary-foreground">
                    {item.badge}
                  </span>
                )}
              </Link>
            )
          })}
        </nav>

        {/* User */}
        <div className="border-t border-sidebar-border p-4">
          <div className="flex items-center gap-3">
            <div className="flex size-9 items-center justify-center rounded-full bg-primary/10">
              <span className="text-sm font-semibold text-primary">AD</span>
            </div>
            <div className="min-w-0 flex-1 overflow-hidden">
              <p className="truncate text-sm font-medium text-sidebar-foreground">Admin</p>
              <p className="truncate text-xs text-muted-foreground">Signed in</p>
            </div>
          </div>
          <Button
            variant="outline"
            size="sm"
            className="mt-3 w-full"
            onClick={() => {
              clearAuthToken()
              router.push('/login')
            }}
          >
            Sign out
          </Button>
        </div>
      </div>
    </aside>
  )
}
