// frontend/src/stores/auth.ts
import { ref } from 'vue'
import { defineStore } from 'pinia'
import axios from 'axios'
import api from '@/api/client'

export const useAuthStore = defineStore('auth', () => {
  const accessToken = ref<string | null>(null)
  const user = ref<{ id: number; username: string } | null>(null)
  const initialized = ref(false)   // ← new

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

  // Call this once on app boot, before mounting
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

  return { accessToken, user, initialized, setAccessToken, clear, login, refresh, fetchMe, logout, init }
})
