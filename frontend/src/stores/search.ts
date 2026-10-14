import { defineStore } from 'pinia'
import { ref } from 'vue'
import api from '@/api/client'

export const useSearchStore = defineStore('search', () => {
  const query   = ref('')
  const artists = ref<any[]>([])
  const albums  = ref<any[]>([])
  const tracks  = ref<any[]>([])
  const loading = ref(false)
  const open    = ref(false)

  let debounce: ReturnType<typeof setTimeout> | null = null

  function reset() {
    artists.value = []
    albums.value  = []
    tracks.value  = []
  }

  async function run(q: string) {
    query.value = q
    if (q.length < 2) {
      reset()
      return
    }
    loading.value = true
    try {
      const { data } = await api.get('/search', { params: { q } })
      artists.value = data.artists
      albums.value  = data.albums
      tracks.value  = data.tracks
    } finally {
      loading.value = false
    }
  }

  function runDebounced(q: string) {
    if (debounce) clearTimeout(debounce)
    debounce = setTimeout(() => run(q), 200)
  }

  function clear() {
    query.value = ''
    reset()
    open.value = false
  }

  return { query, artists, albums, tracks, loading, open, run, runDebounced, clear, reset }
})
