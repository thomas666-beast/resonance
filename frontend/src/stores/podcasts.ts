import { defineStore } from 'pinia'
import { ref } from 'vue'
import api from '@/api/client'
import { useEventsStore } from './events'

export interface PodcastFeed {
  id: number
  feed_url: string
  title: string | null
  description: string | null
  image_url: string | null
  author: string | null
  website_url: string | null
  last_fetched_at: string | null
  last_error: string | null
  subscribed_at: string
  episode_count: number
  latest_episode_at: string | null
}

export const usePodcastsStore = defineStore('podcasts', () => {
  const events  = useEventsStore()

  const feeds   = ref<PodcastFeed[]>([])
  const loaded  = ref(false)
  const loading = ref(false)
  const lastRefresh = ref<{ feed_id: number; inserted: number; updated: number } | null>(null)

  async function load() {
    loading.value = true
    try {
      const { data } = await api.get('/podcasts')
      feeds.value = data.feeds
      loaded.value = true
    } finally {
      loading.value = false
    }
  }

  async function subscribe(feedUrl: string) {
    const { data } = await api.post('/podcasts', { feed_url: feedUrl })
    await load()
    return data as { feed_id: number; job_id: number }
  }

  async function unsubscribe(id: number) {
    await api.delete(`/podcasts/${id}`)
    feeds.value = feeds.value.filter((f) => f.id !== id)
  }

  async function refresh(id: number) {
    await api.post(`/podcasts/${id}/refresh`)
  }

  async function refreshAll() {
    const { data } = await api.post('/podcasts/refresh-all')
    return data as { queued: number }
  }

  function handleEvent(data: any) {
    if (!data || data.event !== 'refreshed') return
    const id = data.feed_id
    if (typeof id !== 'number') return
    lastRefresh.value = {
      feed_id: id,
      inserted: data.inserted ?? 0,
      updated: data.updated ?? 0,
    }
    // Reload the full list — cheap since it's a single query
    load()
  }

  let registered = false
  function connect() {
    if (!registered) {
      events.onMessage((channel, data) => {
        if (channel === 'resonance:podcast') handleEvent(data)
      })
      registered = true
    }
    events.connect()
  }

  return {
    feeds, loaded, loading, lastRefresh,
    load, subscribe, unsubscribe, refresh, refreshAll, connect,
  }
})
