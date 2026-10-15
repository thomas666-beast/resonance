import { defineStore } from 'pinia'
import { ref } from 'vue'
import api from '@/api/client'

export interface RadioStation {
  id: number
  name: string
  stream_url: string
  homepage_url: string | null
  logo_url: string | null
  genre: string | null
  bitrate: number | null
  is_public: boolean
  created_by: number | null
  created_at: string
  updated_at: string
}

export const useRadioStore = defineStore('radio', () => {
  const stations = ref<RadioStation[]>([])
  const isAdmin  = ref(false)
  const loaded   = ref(false)
  const loading  = ref(false)

  async function load() {
    loading.value = true
    try {
      const { data } = await api.get('/radio')
      stations.value = data.stations
      isAdmin.value  = !!data.is_admin
      loaded.value   = true
    } finally {
      loading.value = false
    }
  }

  async function create(payload: Partial<RadioStation>) {
    const { data } = await api.post('/radio', payload)
    stations.value = [...stations.value, data.station]
      .sort((a, b) => a.name.localeCompare(b.name))
    return data.station as RadioStation
  }

  async function update(id: number, payload: Partial<RadioStation>) {
    const { data } = await api.patch(`/radio/${id}`, payload)
    const i = stations.value.findIndex((s) => s.id === id)
    if (i >= 0) stations.value[i] = data.station
    stations.value = [...stations.value]
      .sort((a, b) => a.name.localeCompare(b.name))
    return data.station as RadioStation
  }

  async function remove(id: number) {
    await api.delete(`/radio/${id}`)
    stations.value = stations.value.filter((s) => s.id !== id)
  }

  return { stations, isAdmin, loaded, loading, load, create, update, remove }
})
