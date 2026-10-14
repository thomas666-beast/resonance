import axios from 'axios'

const api = axios.create({
  baseURL: '/api',
  withCredentials: true,
})

// Paths that should never trigger the refresh-and-retry dance.
const NO_RETRY_PATHS = ['/auth/refresh', '/auth/login', '/auth/register']

api.interceptors.request.use((config) => {
  const token = (window as any).__resonance_access_token
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

api.interceptors.response.use(
  (res) => res,
  async (error) => {
    const original = error.config
    const url = original?.url ?? ''

    // Never retry these paths — they ARE the refresh mechanism.
    if (NO_RETRY_PATHS.some((p) => url.includes(p))) {
      return Promise.reject(error)
    }

    if (error.response?.status === 401 && !original._retry) {
      original._retry = true
      try {
        const { data } = await axios.post(
          '/api/auth/refresh',
          {},
          { withCredentials: true },
        )
        ;(window as any).__resonance_access_token = data.access_token
        original.headers.Authorization = `Bearer ${data.access_token}`
        return api(original)
      } catch {
        ;(window as any).__resonance_access_token = null
        // Let the router guard handle navigation — do NOT hard redirect here.
        // window.location.href = '/login'  ← delete this line
      }
    }

    return Promise.reject(error)
  },
)

export default api
