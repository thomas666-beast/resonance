<script setup lang="ts">
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { usePlayerStore } from '@/stores/player'
import { useFavoritesStore } from '@/stores/favorites'
import AlbumCover from '@/components/AlbumCover.vue'

const router = useRouter()
const player = usePlayerStore()
const favorites = useFavoritesStore()

const current = computed(() => player.current)

const coverSrc = computed(() => {
  if (!current.value?.album_id) return null
  const token = (window as any).__resonance_access_token ?? ''
  return `/api/cover/${current.value.album_id}?token=${encodeURIComponent(token)}`
})

const isFavorited = computed(() =>
  current.value ? favorites.isFavorited(current.value.id) : false,
)

const progress = computed(() => {
  if (!player.duration) return 0
  return (player.position / player.duration) * 100
})

function fmt(seconds: number): string {
  if (!isFinite(seconds) || seconds < 0) return '0:00'
  const m = Math.floor(seconds / 60)
  const s = Math.floor(seconds % 60).toString().padStart(2, '0')
  return `${m}:${s}`
}

function onSeekClick(e: MouseEvent) {
  const el = e.currentTarget as HTMLElement
  const rect = el.getBoundingClientRect()
  const ratio = (e.clientX - rect.left) / rect.width
  player.seek(ratio * player.duration)
}

function back() {
  router.back()
}

async function toggleFavorite() {
  if (!current.value) return
  await favorites.toggle(current.value.id)
}
</script>

<template>
  <div v-if="current" class="relative min-h-screen overflow-hidden">
    <!-- Ambient blurred background -->
    <div
      v-if="coverSrc"
      class="absolute inset-0 -z-10 opacity-30 dark:opacity-40"
      :style="{
        backgroundImage: `url(${coverSrc})`,
        backgroundSize: 'cover',
        backgroundPosition: 'center',
        filter: 'blur(80px) saturate(1.4)',
        transform: 'scale(1.2)',
      }"
    />
    <div class="absolute inset-0 -z-10 bg-app/60" />

    <!-- Header -->
    <header class="px-8 py-6 flex items-center">
      <button
        @click="back"
        class="p-2 rounded-full hover-surface transition-colors text-muted"
        :aria-label="$t('nowPlaying.back')"
      >
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
             class="w-5 h-5 fill-none" stroke="currentColor" stroke-width="2"
             stroke-linecap="round" stroke-linejoin="round">
          <path d="M19 12H5M12 19l-7-7 7-7" />
        </svg>
      </button>

      <p class="ml-auto text-label">{{ $t('nowPlaying.label') }}</p>
    </header>

    <!-- Main content -->
    <main class="flex flex-col items-center px-8 pb-16 max-w-2xl mx-auto">
      <!-- Album art -->
      <div class="w-full max-w-md mt-4 mb-10">
        <AlbumCover
          v-if="current.album_id"
          :album-id="current.album_id"
          :rounded="false"
          class="!w-full !h-auto aspect-square !rounded-2xl shadow-2xl"
        />
        <div v-else class="aspect-square bg-surface-2 rounded-2xl flex items-center justify-center">
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
               class="w-1/3 h-1/3 fill-none stroke-muted" stroke-width="1.5">
            <circle cx="12" cy="12" r="9" />
            <circle cx="12" cy="12" r="2" />
          </svg>
        </div>
      </div>

      <!-- Track info -->
      <div class="w-full text-center mb-8">
        <h1 class="text-2xl sm:text-3xl font-semibold tracking-tight text-app truncate">
          {{ current.title }}
        </h1>
        <p class="text-muted mt-2 truncate">
          {{ current.artist_name ?? '—' }}
          <span v-if="current.album_title"> · {{ current.album_title }}</span>
        </p>
      </div>

      <!-- Seek bar -->
      <div class="w-full mb-6">
        <div
          @click="onSeekClick"
          class="group relative h-1.5 bg-surface-2 rounded-full cursor-pointer"
        >
          <div
            class="absolute inset-y-0 left-0 bg-accent rounded-full transition-all"
            :style="{ width: progress + '%' }"
          />
          <div
            class="absolute top-1/2 -translate-y-1/2 w-3 h-3 rounded-full bg-accent
                   shadow-lg opacity-0 group-hover:opacity-100 transition-opacity"
            :style="{ left: `calc(${progress}% - 6px)` }"
          />
        </div>
        <div class="flex justify-between mt-2 text-xs text-muted tabular">
          <span>{{ fmt(player.position) }}</span>
          <span>{{ fmt(player.duration) }}</span>
        </div>
      </div>

      <!-- Controls -->
      <div class="flex items-center gap-8">
        <button
          @click="toggleFavorite"
          class="p-2 rounded-full hover-surface transition-colors"
          :aria-label="isFavorited ? 'Unfavorite' : 'Favorite'"
        >
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
               class="w-6 h-6 transition-colors"
               :class="isFavorited ? 'fill-accent stroke-accent' : 'fill-none stroke-muted'"
               stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z" />
          </svg>
        </button>

        <button
          @click="player.prev()"
          class="p-2 rounded-full hover-surface transition-colors text-app"
          aria-label="Previous"
        >
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
               class="w-7 h-7 fill-current">
            <path d="M6 6h2v12H6zM9.5 12l8.5 6V6z" />
          </svg>
        </button>

        <button
          @click="player.toggle()"
          class="w-20 h-20 rounded-full bg-accent text-white flex items-center
                 justify-center shadow-2xl hover:scale-105 active:scale-95
                 transition-transform"
          :aria-label="player.playing ? 'Pause' : 'Play'"
        >
          <svg v-if="player.playing" xmlns="http://www.w3.org/2000/svg"
               viewBox="0 0 24 24" class="w-9 h-9 fill-current">
            <path d="M6 5h4v14H6zM14 5h4v14h-4z" />
          </svg>
          <svg v-else xmlns="http://www.w3.org/2000/svg"
               viewBox="0 0 24 24" class="w-9 h-9 fill-current ml-1">
            <path d="M8 5v14l11-7z" />
          </svg>
        </button>

        <button
          @click="player.next()"
          class="p-2 rounded-full hover-surface transition-colors text-app"
          aria-label="Next"
        >
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
               class="w-7 h-7 fill-current">
            <path d="M16 6h2v12h-2zM6 18l8.5-6L6 6z" />
          </svg>
        </button>

        <div class="w-10" aria-hidden="true" />
      </div>
    </main>
  </div>

  <!-- Nothing playing -->
  <div v-else class="min-h-screen flex flex-col items-center justify-center text-center px-8">
    <div class="w-24 h-24 rounded-full bg-surface-2 flex items-center justify-center mb-6">
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
           class="w-12 h-12 fill-none stroke-muted" stroke-width="1.5"
           stroke-linecap="round" stroke-linejoin="round">
        <path d="M9 18V5l12-2v13M6 21a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM18 19a3 3 0 1 0 0-6 3 3 0 0 0 0 6z" />
      </svg>
    </div>
    <h2 class="text-title text-app mb-2">{{ $t('nowPlaying.nothing') }}</h2>
    <p class="text-muted">{{ $t('nowPlaying.nothingHint') }}</p>
  </div>
</template>
