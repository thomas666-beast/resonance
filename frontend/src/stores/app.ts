import { defineStore } from 'pinia'
import { ref } from 'vue'
import api from '@/api/client'

interface AppInfo {
  name: string
  copyright_year: string | number
  admin_contact: string
}

export const useAppStore = defineStore('app', () => {
  const info = ref<AppInfo>({
    name: 'Resonance',
    copyright_year: new Date().getFullYear(),
    admin_contact: '',
  })
  const loaded = ref(false)

  async function load() {
    if (loaded.value) return
    try {
      const { data } = await api.get('/health')
      if (data.app) {
        info.value = {
          name:           data.app.name           ?? 'Resonance',
          copyright_year: data.app.copyright_year ?? new Date().getFullYear(),
          admin_contact:  data.app.admin_contact  ?? '',
        }
      }
      loaded.value = true
    } catch {
      // silent — footer falls back to defaults
    }
  }

  return { info, loaded, load }
})
