const STORAGE_KEY = 'smartafya_admin_access_token'

export function getAuthToken(): string | null {
  if (typeof window === 'undefined') return null
  return localStorage.getItem(STORAGE_KEY)
}

export function setAuthToken(token: string) {
  localStorage.setItem(STORAGE_KEY, token)
}

export function clearAuthToken() {
  localStorage.removeItem(STORAGE_KEY)
}
