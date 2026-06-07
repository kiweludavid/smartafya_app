'use client'

import { useEffect, useState } from 'react'
import Image from 'next/image'
import { useRouter } from 'next/navigation'
import { login, type ApiError } from '@/lib/api'
import { getAuthToken, setAuthToken } from '@/lib/auth-storage'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Spinner } from '@/components/ui/spinner'

export default function LoginPage() {
  const router = useRouter()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [submitting, setSubmitting] = useState(false)

  useEffect(() => {
    if (getAuthToken()) router.replace('/')
  }, [router])

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError(null)
    setSubmitting(true)
    try {
      const res = await login(email.trim(), password)
      setAuthToken(res.access_token)
      router.replace('/')
    } catch (e: unknown) {
      const isApi = (x: unknown): x is ApiError =>
        typeof x === 'object' && x !== null && 'status' in x && 'message' in x
      if (isApi(e)) {
        const hint =
          e.status === 401
            ? ' If you use custom admin credentials, ensure the backend .env matches and the API has been restarted.'
            : ''
        setError(`${e.message}${hint}`)
      } else {
        setError('Sign-in failed.')
      }
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-background p-4">
      <Card className="w-full max-w-md border-border">
        <CardHeader className="space-y-1">
          <div className="mb-2 flex justify-center">
            <div className="flex size-14 items-center justify-center overflow-hidden rounded-full border border-border bg-white shadow-sm">
              <Image src="/smartafya-logo.png" alt="Smart Afya" width={56} height={56} className="size-14 object-cover" priority />
            </div>
          </div>
          <CardTitle className="text-center text-xl">Admin sign in</CardTitle>
          <CardDescription className="text-center">
            Connects to the Smart Afya API at{' '}
            <span className="font-mono text-xs">{process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:8000'}</span>
          </CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="email">Email</Label>
              <Input
                id="email"
                type="email"
                autoComplete="username"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
                disabled={submitting}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="password">Password</Label>
              <Input
                id="password"
                type="password"
                autoComplete="current-password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                disabled={submitting}
              />
            </div>
            {error && <p className="text-sm text-destructive">{error}</p>}
            <Button type="submit" className="w-full" disabled={submitting}>
              {submitting ? (
                <>
                  <Spinner className="mr-2 size-4" />
                  Signing in…
                </>
              ) : (
                'Sign in'
              )}
            </Button>
          </form>
        </CardContent>
      </Card>
    </div>
  )
}
