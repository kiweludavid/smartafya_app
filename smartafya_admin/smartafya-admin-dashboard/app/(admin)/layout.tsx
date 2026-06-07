'use client'

import { PropsWithChildren, useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { AdminSidebar } from '@/components/admin-sidebar'
import { Spinner } from '@/components/ui/spinner'
import { getAuthToken } from '@/lib/auth-storage'

export default function AdminLayout({ children }: PropsWithChildren) {
  const router = useRouter()
  const [ready, setReady] = useState(false)

  useEffect(() => {
    if (!getAuthToken()) {
      router.replace('/login')
      return
    }
    setReady(true)
  }, [router])

  if (!ready) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-background">
        <Spinner className="size-8 text-muted-foreground" />
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-background">
      <AdminSidebar />
      <main className="ml-[220px] min-h-screen">{children}</main>
    </div>
  )
}

