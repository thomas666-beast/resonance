<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import { useI18n } from 'vue-i18n'
import api from '@/api/client'
import { usePlayerStore, type PodcastEpisode } from '@/stores/player'

const { t } = useI18n()
const route = useRoute()
const player = usePlayerStore()

interface Feed {
  id: number
  feed_url: string
  title: string | null
  description: string | null
  image_url: string | null
  author: string | null
  website_url: string | null
  last_fetched_at: string | null
  last_error: string | null
}

interface EpisodeRow extends PodcastEpisode {
  progress_position_sec?: number
  progress_duration_sec?: number | null
  progress_completed?: boolean
}

interface Progress {
  position_sec: number
  duration_sec: number | null
  completed: boolean
}

const feed     = ref<Feed | null>(null)
const episodes = ref<EpisodeRow[]>([])
const progress = ref<Record<number, Progress>>({})
const loading  = ref(true)
const error    = ref<string | null>(null)

async function load() {
  loading.value = true
  error.value = null
  try {
    const { data } = await api.get(`/podcasts/${route.params.id}`)
    feed.value     = data.feed
    episodes.value = data.episodes

    // Progress is embedded in each episode row by the backend,
    // so no additional requests per episode.
    const map: Record<number, Progress> = {}
    for (const e of data.episodes as EpisodeRow[]) {
      map[e.id] = {
        position_sec: e.progress_position_sec ?? 0,
        duration_sec: e.progress_duration_sec ?? null,
        completed:    !!e.progress_completed,
      }
    }
    progress.value = map
  } catch (e: any) {
    error.value = e.response?.data?.error ?? 'Failed to load podcast'
  } finally {
    loading.value = false
  }
}

function playEpisode(ep: EpisodeRow) {
  const p = progress.value[ep.id]
  const startAt = (p && !p.completed) ? (p.position_sec ?? 0) : 0
  player.playEpisode(ep, startAt)
}

function fmt(seconds: number | null | undefined): string {
  if (!seconds) return '—'
  const m = Math.floor(seconds / 60)
  const s = Math.floor(seconds % 60).toString().padStart(2, '0')
  return `${m}:${s}`
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return ''
  return new Date(s).toLocaleDateString()
}

function pct(ep: EpisodeRow): number {
  const p = progress.value[ep.id]
  if (!p || !p.duration_sec) return 0
  if (p.completed) return 100
  return Math.min(100, Math.round((p.position_sec / p.duration_sec) * 100))
}

onMounted(load)
</script>

<template>
  <div class="p-4 md:p-8 pb-32 max-w-4xl mx-auto text-app">
    <p v-if="loading" class="text-muted">{{ $t('common.loading') }}</p>
    <p v-else-if="error" class="text-danger">{{ error }}</p>

    <template v-else-if="feed">
      <header class="mb-10 flex flex-col sm:flex-row gap-6">
        <div class="w-40 h-40 rounded-xl bg-surface-2 overflow-hidden shrink-0">
          <img v-if="feed.image_url" :src="feed.image_url" class="w-full h-full object-cover" alt="" />
          <div v-else class="w-full h-full flex items-center justify-center">
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
                 class="w-16 h-16 fill-none stroke-muted" stroke-width="1.5">
              <rect x="3" y="4" width="18" height="16" rx="2"/>
              <circle cx="12" cy="12" r="3"/>
              <path d="M3 8h18" />
            </svg>
          </div>
        </div>
        <div class="flex flex-col justify-end">
          <p class="text-label mb-2">{{ $t('podcasts.label') }}</p>
          <h1 class="text-display">{{ feed.title || feed.feed_url }}</h1>
          <p v-if="feed.author" class="text-muted mt-2">{{ feed.author }}</p>
          <p class="text-muted text-sm mt-1">
            {{ $t('podcasts.episodeCount', { n: episodes.length }) }}
          </p>
          <p v-if="feed.last_error" class="text-danger text-sm mt-2">
            {{ $t('podcasts.lastError') }}: {{ feed.last_error }}
          </p>
        </div>
      </header>

      <div class="space-y-2">
        <div
          v-for="ep in episodes"
          :key="ep.id"
          class="bg-surface border border-app rounded-xl p-4 hover:border-hi transition-colors cursor-pointer"
          @click="playEpisode(ep)"
        >
          <div class="flex items-start gap-3">
            <div class="flex-1 min-w-0">
              <div class="text-sm font-medium text-app">{{ ep.title }}</div>
              <div class="text-xs text-muted mt-1 flex items-center gap-3">
                <span v-if="ep.published_at">{{ fmtDate(ep.published_at) }}</span>
                <span v-if="ep.duration_sec">{{ fmt(ep.duration_sec) }}</span>
                <span v-if="progress[ep.id]?.completed" class="text-accent">
                  {{ $t('podcasts.played') }}
                </span>
              </div>
            </div>
          </div>

          <div v-if="pct(ep) > 0 && pct(ep) < 100"
               class="mt-3 h-1 bg-surface-2 rounded-full overflow-hidden">
            <div class="h-full bg-accent transition-all" :style="{ width: pct(ep) + '%' }" />
          </div>
        </div>
      </div>
    </template>
  </div>
</template>
