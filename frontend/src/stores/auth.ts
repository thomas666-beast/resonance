import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import axios from 'axios'
import api from '@/api/client'

interface User {
  id: number
  username: string
  role?: 'user' | 'admin'
}

export const useAuthStore = defineStore('auth', () => {
  const accessToken = ref<string | null>(null)
  const user = ref<User | null>(null)
  const initialized = ref(false)

  const isAdmin = computed(() => user.value?.role === 'admin')

  function setAccessToken(token: string | null) {
    accessToken.value = token
    ;(window as any).__resonance_access_token = token
  }

  function clear() {
    setAccessToken(null)
    user.value = null
  }

  async function fetchMe() {
    const { data } = await api.get('/auth/me')
    user.value = data.user
  }

  async function refresh() {
    try {
      const { data } = await axios.post('/api/auth/refresh', {}, { withCredentials: true })
      setAccessToken(data.access_token)
      await fetchMe()
      return true
    } catch {
      clear()
      return false
    }
  }

  async function init() {
    if (initialized.value) return
    await refresh()
    initialized.value = true
  }

  async function login(username: string, password: string) {
    const { data } = await api.post('/auth/login', { username, password })
    setAccessToken(data.access_token)
    user.value = data.user
    initialized.value = true
    return data
  }

  async function logout() {
    try { await api.post('/auth/logout') } finally { clear() }
  }

  return { accessToken, user, initialized, isAdmin,
           setAccessToken, clear, login, refresh, fetchMe, logout, init }
})
