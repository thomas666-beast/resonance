import { defineStore } from 'pinia'
import { ref } from 'vue'
import api from '@/api/client'

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
  const feeds   = ref<PodcastFeed[]>([])
  const loaded  = ref(false)
  const loading = ref(false)

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
    // The refresh job runs async; reload after a short delay
    await new Promise((r) => setTimeout(r, 800))
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
    await new Promise((r) => setTimeout(r, 1500))
    await load()
    return data as { queued: number }
  }

  return { feeds, loaded, loading, load, subscribe, unsubscribe, refresh, refreshAll }
})
