import { defineStore } from 'pinia'
import { ref } from 'vue'
import api from '@/api/client'
import type { Track } from './player'

export interface Playlist {
  id: number
  name: string
  description: string | null
  is_public: boolean
  track_count: number
  created_at: string
}

export const usePlaylistsStore = defineStore('playlists', () => {
  const items = ref<Playlist[]>([])
  const loaded = ref(false)

  async function load() {
    const { data } = await api.get('/playlists')
    items.value = data.playlists
    loaded.value = true
  }

  async function create(name: string, description?: string, is_public = false) {
    const { data } = await api.post('/playlists', { name, description, is_public })
    items.value = [data.playlist, ...items.value]
    return data.playlist as Playlist
  }

  async function remove(id: number) {
    await api.delete(`/playlists/${id}`)
    items.value = items.value.filter((p) => p.id !== id)
  }

  async function addTrack(playlistId: number, trackId: number) {
    const { data } = await api.post(`/playlists/${playlistId}/tracks`, { track_id: trackId })
    const pl = items.value.find((p) => p.id === playlistId)
    if (pl) pl.track_count = data.track_count
  }

  async function removeTrack(playlistId: number, trackId: number) {
    const { data } = await api.delete(`/playlists/${playlistId}/tracks/${trackId}`)
    const pl = items.value.find((p) => p.id === playlistId)
    if (pl) pl.track_count = data.track_count
  }

  async function reorder(playlistId: number, orderedIds: number[]) {
    await api.patch(`/playlists/${playlistId}/reorder`, { track_ids: orderedIds })
  }

  async function detail(id: number): Promise<{ playlist: Playlist; tracks: Track[] }> {
    const { data } = await api.get(`/playlists/${id}`)
    return data
  }

  return { items, loaded, load, create, remove, addTrack, removeTrack, reorder, detail }
})
