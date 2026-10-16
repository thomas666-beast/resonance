<script setup lang="ts">
import { RouterLink } from 'vue-router'
import { useI18n } from 'vue-i18n'
import type { PodcastFeed } from '@/stores/podcasts'

defineProps<{ feed: PodcastFeed }>()
const emit = defineEmits<{ (e: 'unsubscribe'): void; (e: 'refresh'): void }>()

const { t } = useI18n()

function fmtDate(s: string | null): string {
  if (!s) return t('podcasts.never')
  return new Date(s).toLocaleDateString()
}
</script>

<template>
  <div class="group relative bg-surface border border-app rounded-xl p-4
              hover:shadow-xl hover:-translate-y-0.5 transition-all">
    <!-- Actions -->
    <div class="absolute top-3 right-3 z-10 flex items-center gap-1">
      <button
        @click.stop="emit('refresh')"
        class="p-1.5 rounded-full hover:bg-surface-2 text-muted transition-colors"
        :aria-label="t('podcasts.refresh')"
        :title="t('podcasts.refresh')"
      >
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
             class="w-4 h-4 fill-none" stroke="currentColor" stroke-width="2"
             stroke-linecap="round" stroke-linejoin="round">
          <path d="M21 12a9 9 0 1 1-2.64-6.36M21 3v6h-6"/>
        </svg>
      </button>
      <button
        @click.stop="emit('unsubscribe')"
        class="p-1.5 rounded-full hover:bg-surface-2 text-muted hover:text-danger transition-colors"
        :aria-label="t('podcasts.unsubscribe')"
        :title="t('podcasts.unsubscribe')"
      >
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
             class="w-4 h-4 fill-none" stroke="currentColor" stroke-width="2"
             stroke-linecap="round" stroke-linejoin="round">
          <path d="M3 6h18M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/>
        </svg>
      </button>
    </div>

    <RouterLink :to="`/podcasts/${feed.id}`" class="flex items-start gap-4">
      <div class="w-16 h-16 rounded-lg bg-surface-2 overflow-hidden shrink-0 flex items-center justify-center">
        <img v-if="feed.image_url" :src="feed.image_url" class="w-full h-full object-cover" alt="" />
        <svg v-else xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
             class="w-8 h-8 fill-none stroke-muted" stroke-width="1.5">
          <rect x="3" y="4" width="18" height="16" rx="2"/>
          <circle cx="12" cy="12" r="3"/>
          <path d="M3 8h18" />
        </svg>
      </div>

      <div class="min-w-0 flex-1 pr-16">
        <div class="text-sm font-medium text-app truncate">
          {{ feed.title || feed.feed_url }}
        </div>
        <div v-if="feed.author" class="text-xs text-muted truncate mt-0.5">
          {{ feed.author }}
        </div>
        <div class="text-xs text-muted mt-2 flex items-center gap-3">
          <span>{{ t('podcasts.episodeCount', { n: feed.episode_count }) }}</span>
          <span class="text-dim">·</span>
          <span>{{ t('podcasts.lastFetched') }}: {{ fmtDate(feed.last_fetched_at) }}</span>
        </div>
        <div v-if="feed.last_error" class="text-xs text-danger mt-1 truncate">
          {{ feed.last_error }}
        </div>
      </div>
    </RouterLink>
  </div>
</template>
