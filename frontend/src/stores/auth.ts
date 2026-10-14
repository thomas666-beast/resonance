import { defineStore } from 'pinia'
import { ref } from 'vue'
import api from '@/api/client'

export const useAuthStore = defineStore('auth', () => {
  const accessToken = ref<string | null>(null)
  const user = ref<{ id: number; username: string } | null>(null)
  const isReady = ref(false)

  function setAccessToken(token: string) {
    accessToken.value = token
  }

function clear() {
  accessToken.value = null
  user.value = null
  ;(window as any).__resonance_access_token = null
}

  async function login(username: string, password: string) {
    const { data } = await api.post('/auth/login', { username, password })
    accessToken.value = data.access_token
    user.value = data.user
    return data
  }

async function refresh() {
  try {
    const { data } = await api.post('/api/auth/refresh', {}, { withCredentials: true })
    setAccessToken(data.access_token)
    // Restore user object after refresh
    await fetchMe()
    return true
  } catch {
    clear()
    return false
  }
}

async function fetchMe() {
  const { data } = await api.get('/auth/me')
  user.value = data.user
}

  async function logout() {
    try {
      await api.post('/auth/logout')
    } finally {
      clear()
    }
  }

  return { accessToken, user, isReady, setAccessToken, clear, login, refresh, fetchMe, logout }
})
