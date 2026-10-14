import { defineStore } from 'pinia'
import { ref } from 'vue'
import api from '@/api/client'

export const useFavoritesStore = defineStore('favorites', () => {
  const ids = ref<Set<number>>(new Set())
  const loaded = ref(false)

  async function load() {
    const { data } = await api.get('/favorites/ids')
    ids.value = new Set(data.track_ids)
    loaded.value = true
  }

  function isFavorited(trackId: number): boolean {
    return ids.value.has(trackId)
  }

  async function toggle(trackId: number) {
    const wasFavorited = ids.value.has(trackId)

    // Optimistic flip
    if (wasFavorited) ids.value.delete(trackId)
    else              ids.value.add(trackId)
    // Trigger reactivity for Set
    ids.value = new Set(ids.value)

    try {
      if (wasFavorited) {
        await api.delete(`/favorites/${trackId}`)
      } else {
        await api.post(`/favorites/${trackId}`)
      }
    } catch {
      // Revert on failure
      if (wasFavorited) ids.value.add(trackId)
      else              ids.value.delete(trackId)
      ids.value = new Set(ids.value)
    }
  }

  return { ids, loaded, load, isFavorited, toggle }
})
