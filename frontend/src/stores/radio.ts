import { defineStore } from 'pinia'
import { ref } from 'vue'
import api from '@/api/client'
import { useEventsStore } from './events'

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
  const events = useEventsStore()

  const stations   = ref<RadioStation[]>([])
  const isAdmin    = ref(false)
  const loaded     = ref(false)
  const loading    = ref(false)
  const nowPlaying = ref<Record<number, string | null>>({})

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

  async function fetchNowPlaying(id: number) {
    try {
      const { data } = await api.get(`/radio/${id}/now-playing`)
      nowPlaying.value = { ...nowPlaying.value, [id]: data.title ?? null }
    } catch {
      // silent
    }
  }

  function handleEvent(data: any) {
    if (!data || typeof data !== 'object') return
    const id = data.station_id
    if (typeof id !== 'number') return
    if (typeof data.title === 'string' && data.title.length) {
      nowPlaying.value = { ...nowPlaying.value, [id]: data.title }
    }
  }

  let registered = false
  function connect() {
    if (!registered) {
      events.onMessage((channel, data) => {
        if (channel === 'resonance:radio') handleEvent(data)
      })
      registered = true
    }
    events.connect()
  }

  return {
    stations, isAdmin, loaded, loading, nowPlaying,
    load, create, update, remove, fetchNowPlaying, connect,
  }
})
