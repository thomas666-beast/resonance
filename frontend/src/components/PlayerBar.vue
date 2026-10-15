<script setup lang="ts">
import { computed, ref } from 'vue'
import { RouterLink } from 'vue-router'
import { usePlayerStore } from '@/stores/player'
import AlbumCover from './AlbumCover.vue'

const emit = defineEmits<{ (e: 'open-queue'): void }>()

const player = usePlayerStore()

const seeking = ref(false)
const seekValue = ref(0)

const displayPosition = computed(() =>
  seeking.value ? seekValue.value : player.position,
)

const coverSrc = computed(() => {
  if (player.isLive && player.currentRadio?.logo_url) {
    return player.currentRadio.logo_url
  }
  return null
})

function fmt(seconds: number): string {
  if (!isFinite(seconds) || seconds < 0) return '0:00'
  const m = Math.floor(seconds / 60)
  const s = Math.floor(seconds % 60).toString().padStart(2, '0')
  return `${m}:${s}`
}

function onSeekInput(e: Event) {
  seeking.value = true
  seekValue.value = Number((e.target as HTMLInputElement).value)
}

function onSeekCommit() {
  player.seek(seekValue.value)
  seeking.value = false
}

function onVolumeInput(e: Event) {
  player.setVolume(Number((e.target as HTMLInputElement).value))
}
</script>

<template>
  <div
    v-if="player.current || player.currentRadio"
    class="border-t border-app bg-surface/95 backdrop-blur-sm shadow-2xl text-app"
  >
    <!-- Desktop -->
    <div class="hidden md:flex px-6 py-3 items-center gap-4">
      <!-- Radio -->
      <template v-if="player.isLive">
        <div class="flex items-center gap-3 min-w-0 flex-1">
          <div class="w-10 h-10 rounded bg-surface-2 flex items-center justify-center overflow-hidden shrink-0">
            <img v-if="coverSrc" :src="coverSrc" class="w-full h-full object-cover" alt="" />
            <svg v-else xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
                 class="w-5 h-5 fill-none stroke-muted" stroke-width="1.75">
              <circle cx="12" cy="12" r="3" />
              <path d="M4.22 4.22a12 12 0 0 0 0 15.56M19.78 4.22a12 12 0 0 1 0 15.56M7.76 7.76a6 6 0 0 0 0 8.48M16.24 7.76a6 6 0 0 1 0 8.48" />
            </svg>
          </div>
          <div class="min-w-0">
            <div class="text-sm font-medium truncate">{{ player.currentRadio?.name }}</div>
            <div class="text-xs text-muted truncate">
              <span class="text-accent font-medium">LIVE</span>
              <span v-if="player.currentRadio?.genre"> · {{ player.currentRadio.genre }}</span>
            </div>
          </div>
        </div>

        <button
          @click="player.toggle()"
          class="w-10 h-10 rounded-full bg-accent text-white flex items-center
                 justify-center hover:scale-105 active:scale-95 transition-transform"
          :aria-label="player.playing ? 'Pause' : 'Play'"
        >
          <svg v-if="player.playing" xmlns="http://www.w3.org/2000/svg"
               viewBox="0 0 24 24" class="w-4 h-4 fill-current">
            <path d="M6 5h4v14H6zM14 5h4v14h-4z" />
          </svg>
          <svg v-else xmlns="http://www.w3.org/2000/svg"
               viewBox="0 0 24 24" class="w-4 h-4 fill-current ml-0.5">
            <path d="M8 5v14l11-7z" />
          </svg>
        </button>

        <button
          @click="player.stop()"
          class="p-2 rounded-full hover:bg-surface-2 transition-colors text-muted hover:text-app"
          :aria-label="$t('radio.stop')"
        >
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
               class="w-5 h-5 fill-none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
            <path d="M18 6 6 18M6 6l12 12" />
          </svg>
        </button>

        <div class="flex items-center gap-2 w-32">
          <span class="text-xs text-muted">🔊</span>
          <input type="range" min="0" max="1" step="0.01"
                 :value="player.volume" @input="onVolumeInput"
                 class="flex-1" aria-label="Volume" />
        </div>
      </template>

      <!-- Library track -->
      <template v-else-if="player.current">
        <RouterLink to="/now-playing" class="flex items-center gap-3 min-w-0 flex-1 group">
          <AlbumCover
            v-if="player.current.album_id"
            :album-id="player.current.album_id"
            size="sm"
            class="group-hover:shadow-lg transition-shadow"
          />
          <div class="min-w-0">
            <div class="text-sm font-medium truncate group-hover:text-accent transition-colors">
              {{ player.current.title }}
            </div>
            <div class="text-xs text-muted truncate">
              {{ player.current.artist_name ?? '—' }}
              <span v-if="player.current.album_title"> · {{ player.current.album_title }}</span>
            </div>
          </div>
        </RouterLink>

        <div class="flex items-center gap-2">
          <button @click="player.prev()" class="p-2 rounded-full hover:bg-surface-2 transition-colors text-app" aria-label="Previous">
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="w-5 h-5 fill-current">
              <path d="M6 6h2v12H6zM9.5 12l8.5 6V6z" />
            </svg>
          </button>
          <button
            @click="player.toggle()"
            class="w-10 h-10 rounded-full bg-accent text-white flex items-center justify-center hover:scale-105 active:scale-95 transition-transform"
            :aria-label="player.playing ? 'Pause' : 'Play'"
          >
            <svg v-if="player.playing" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="w-4 h-4 fill-current">
              <path d="M6 5h4v14H6zM14 5h4v14h-4z" />
            </svg>
            <svg v-else xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="w-4 h-4 fill-current ml-0.5">
              <path d="M8 5v14l11-7z" />
            </svg>
          </button>
          <button @click="player.next()" class="p-2 rounded-full hover:bg-surface-2 transition-colors text-app" aria-label="Next">
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="w-5 h-5 fill-current">
              <path d="M16 6h2v12h-2zM6 18l8.5-6L6 6z" />
            </svg>
          </button>
        </div>

        <div class="flex-1 flex items-center gap-3">
          <span class="text-xs text-muted w-10 text-right tabular">{{ fmt(displayPosition) }}</span>
          <input
            type="range" min="0" :max="player.duration || 0" step="0.1"
            :value="displayPosition" @input="onSeekInput" @change="onSeekCommit"
            class="flex-1" aria-label="Seek"
          />
          <span class="text-xs text-muted w-10 tabular">{{ fmt(player.duration) }}</span>
        </div>

        <button
          @click="emit('open-queue')"
          class="relative p-2 rounded-full hover:bg-surface-2 transition-colors text-muted hover:text-app"
          :aria-label="$t('queue.title')"
        >
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="w-5 h-5 fill-none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
            <path d="M4 6h16M4 12h10M4 18h13" />
          </svg>
          <span v-if="player.upcoming.length"
                class="absolute -top-0.5 -right-0.5 min-w-[18px] h-[18px] px-1 rounded-full bg-accent text-white text-[10px] font-medium flex items-center justify-center">
            {{ player.upcoming.length }}
          </span>
        </button>

        <div class="flex items-center gap-2 w-32">
          <span class="text-xs text-muted">🔊</span>
          <input type="range" min="0" max="1" step="0.01"
                 :value="player.volume" @input="onVolumeInput"
                 class="flex-1" aria-label="Volume" />
        </div>
      </template>
    </div>

    <!-- Mobile -->
    <div class="md:hidden">
      <!-- Radio -->
      <template v-if="player.isLive">
        <div class="flex items-center gap-3 px-4 py-3">
          <div class="w-10 h-10 rounded bg-surface-2 flex items-center justify-center overflow-hidden shrink-0">
            <img v-if="coverSrc" :src="coverSrc" class="w-full h-full object-cover" alt="" />
            <svg v-else xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
                 class="w-5 h-5 fill-none stroke-muted" stroke-width="1.75">
              <circle cx="12" cy="12" r="3" />
              <path d="M4.22 4.22a12 12 0 0 0 0 15.56M19.78 4.22a12 12 0 0 1 0 15.56M7.76 7.76a6 6 0 0 0 0 8.48M16.24 7.76a6 6 0 0 1 0 8.48" />
            </svg>
          </div>
          <div class="min-w-0 flex-1">
            <div class="text-sm font-medium truncate text-app">{{ player.currentRadio?.name }}</div>
            <div class="text-xs text-muted truncate">
              <span class="text-accent font-medium">LIVE</span>
              <span v-if="player.currentRadio?.genre"> · {{ player.currentRadio.genre }}</span>
            </div>
          </div>
          <button
            @click="player.toggle()"
            class="w-11 h-11 rounded-full bg-accent text-white flex items-center justify-center active:scale-95 transition-transform shrink-0"
            :aria-label="player.playing ? 'Pause' : 'Play'"
          >
            <svg v-if="player.playing" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="w-5 h-5 fill-current">
              <path d="M6 5h4v14H6zM14 5h4v14h-4z" />
            </svg>
            <svg v-else xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="w-5 h-5 fill-current ml-0.5">
              <path d="M8 5v14l11-7z" />
            </svg>
          </button>
          <button
            @click="player.stop()"
            class="p-2 text-muted active:text-app transition-colors"
            :aria-label="$t('radio.stop')"
          >
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
                 class="w-5 h-5 fill-none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
              <path d="M18 6 6 18M6 6l12 12" />
            </svg>
          </button>
        </div>
      </template>

      <!-- Library track -->
      <template v-else-if="player.current">
        <RouterLink to="/now-playing" class="flex items-center gap-3 px-4 pt-3 pb-2">
          <AlbumCover v-if="player.current.album_id" :album-id="player.current.album_id" size="sm" />
          <div class="min-w-0 flex-1">
            <div class="text-sm font-medium truncate text-app">{{ player.current.title }}</div>
            <div class="text-xs text-muted truncate">
              {{ player.current.artist_name ?? '—' }}
              <span v-if="player.current.album_title"> · {{ player.current.album_title }}</span>
            </div>
          </div>
          <button
            @click.stop.prevent="emit('open-queue')"
            class="relative p-2 rounded-full active:bg-surface-2 transition-colors text-muted"
            :aria-label="$t('queue.title')"
          >
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="w-5 h-5 fill-none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
              <path d="M4 6h16M4 12h10M4 18h13" />
            </svg>
            <span v-if="player.upcoming.length"
                  class="absolute -top-0.5 -right-0.5 min-w-[16px] h-[16px] px-1 rounded-full bg-accent text-white text-[10px] font-medium flex items-center justify-center">
              {{ player.upcoming.length }}
            </span>
          </button>
        </RouterLink>

        <div class="px-4 pb-3 flex items-center gap-3">
          <button @click="player.prev()" class="p-2 text-muted active:text-app active:scale-95 transition-all" aria-label="Previous">
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="w-6 h-6 fill-current">
              <path d="M6 6h2v12H6zM9.5 12l8.5 6V6z" />
            </svg>
          </button>
          <button
            @click="player.toggle()"
            class="w-11 h-11 rounded-full bg-accent text-white flex items-center justify-center active:scale-95 transition-transform shrink-0"
            :aria-label="player.playing ? 'Pause' : 'Play'"
          >
            <svg v-if="player.playing" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="w-5 h-5 fill-current">
              <path d="M6 5h4v14H6zM14 5h4v14h-4z" />
            </svg>
            <svg v-else xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="w-5 h-5 fill-current ml-0.5">
              <path d="M8 5v14l11-7z" />
            </svg>
          </button>
          <button @click="player.next()" class="p-2 text-muted active:text-app active:scale-95 transition-all" aria-label="Next">
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="w-6 h-6 fill-current">
              <path d="M16 6h2v12h-2zM6 18l8.5-6L6 6z" />
            </svg>
          </button>
          <div class="flex-1 flex items-center gap-2 min-w-0">
            <span class="text-[10px] text-muted tabular shrink-0">{{ fmt(displayPosition) }}</span>
            <input type="range" min="0" :max="player.duration || 0" step="0.1"
                   :value="displayPosition" @input="onSeekInput" @change="onSeekCommit"
                   class="flex-1 min-w-0" aria-label="Seek" />
            <span class="text-[10px] text-muted tabular shrink-0">{{ fmt(player.duration) }}</span>
          </div>
        </div>
      </template>
    </div>
  </div>
</template>
