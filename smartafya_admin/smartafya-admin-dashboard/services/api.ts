import axios from 'axios'
import { clearAuthToken, getAuthToken } from '@/lib/auth-storage'

const DEFAULT_BASE_URL = 'http://localhost:8000'
const DEFAULT_TIMEOUT_MS = 15000

export const api = axios.create({
  baseURL: (process.env.NEXT_PUBLIC_API_BASE_URL || DEFAULT_BASE_URL).replace(/\/$/, ''),
  timeout: Number(process.env.NEXT_PUBLIC_API_TIMEOUT_MS) || DEFAULT_TIMEOUT_MS,
  headers: {
    Accept: 'application/json',
  },
})

api.interceptors.request.use((config) => {
  const token = getAuthToken()
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

api.interceptors.response.use(
  (res) => res,
  (err: unknown) => {
    const status = axios.isAxiosError(err) ? err.response?.status : undefined
    if (status === 401 && typeof window !== 'undefined') {
      clearAuthToken()
      if (!window.location.pathname.startsWith('/login')) window.location.href = '/login'
    }
    return Promise.reject(err)
  }
)

