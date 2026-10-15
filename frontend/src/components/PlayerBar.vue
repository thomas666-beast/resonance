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
    v-if="player.current"
    class="fixed bottom-0 left-0 right-0 border-t border-app bg-surface/95 backdrop-blur-sm
           shadow-2xl z-30 text-app"
  >
    <!-- Desktop layout -->
    <div class="hidden md:flex px-6 py-3 items-center gap-4">
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
        <button
          @click="player.prev()"
          class="p-2 rounded-full hover:bg-surface-2 transition-colors text-app"
          aria-label="Previous"
        >
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="w-5 h-5 fill-current">
            <path d="M6 6h2v12H6zM9.5 12l8.5 6V6z" />
          </svg>
        </button>
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
          @click="player.next()"
          class="p-2 rounded-full hover:bg-surface-2 transition-colors text-app"
          aria-label="Next"
        >
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="w-5 h-5 fill-current">
            <path d="M16 6h2v12h-2zM6 18l8.5-6L6 6z" />
          </svg>
        </button>
      </div>

      <div class="flex-1 flex items-center gap-3">
        <span class="text-xs text-muted w-10 text-right tabular">
          {{ fmt(displayPosition) }}
        </span>
        <input
          type="range"
          min="0"
          :max="player.duration || 0"
          step="0.1"
          :value="displayPosition"
          @input="onSeekInput"
          @change="onSeekCommit"
          class="flex-1"
          aria-label="Seek"
        />
        <span class="text-xs text-muted w-10 tabular">{{ fmt(player.duration) }}</span>
      </div>

      <button
        @click="emit('open-queue')"
        class="relative p-2 rounded-full hover:bg-surface-2 transition-colors text-muted hover:text-app"
        :aria-label="$t('queue.title')"
        :title="$t('queue.title')"
      >
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
             class="w-5 h-5 fill-none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
          <path d="M4 6h16M4 12h10M4 18h13" />
        </svg>
        <span
          v-if="player.upcoming.length"
          class="absolute -top-0.5 -right-0.5 min-w-[18px] h-[18px] px-1 rounded-full
                 bg-accent text-white text-[10px] font-medium flex items-center justify-center"
        >
          {{ player.upcoming.length }}
        </span>
      </button>

      <div class="flex items-center gap-2 w-32">
        <span class="text-xs text-muted">🔊</span>
        <input
          type="range"
          min="0"
          max="1"
          step="0.01"
          :value="player.volume"
          @input="onVolumeInput"
          class="flex-1"
          aria-label="Volume"
        />
      </div>
    </div>

    <!-- Mobile layout -->
    <div class="md:hidden">
      <RouterLink to="/now-playing" class="flex items-center gap-3 px-4 pt-3 pb-2">
        <AlbumCover
          v-if="player.current.album_id"
          :album-id="player.current.album_id"
          size="sm"
        />
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
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
               class="w-5 h-5 fill-none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
            <path d="M4 6h16M4 12h10M4 18h13" />
          </svg>
          <span
            v-if="player.upcoming.length"
            class="absolute -top-0.5 -right-0.5 min-w-[16px] h-[16px] px-1 rounded-full
                   bg-accent text-white text-[10px] font-medium flex items-center justify-center"
          >
            {{ player.upcoming.length }}
          </span>
        </button>
      </RouterLink>

      <div class="px-4 pb-3 flex items-center gap-3">
        <button
          @click="player.prev()"
          class="p-2 text-muted active:text-app active:scale-95 transition-all"
          aria-label="Previous"
        >
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="w-6 h-6 fill-current">
            <path d="M6 6h2v12H6zM9.5 12l8.5 6V6z" />
          </svg>
        </button>

        <button
          @click="player.toggle()"
          class="w-11 h-11 rounded-full bg-accent text-white flex items-center
                 justify-center active:scale-95 transition-transform shrink-0"
          :aria-label="player.playing ? 'Pause' : 'Play'"
        >
          <svg v-if="player.playing" xmlns="http://www.w3.org/2000/svg"
               viewBox="0 0 24 24" class="w-5 h-5 fill-current">
            <path d="M6 5h4v14H6zM14 5h4v14h-4z" />
          </svg>
          <svg v-else xmlns="http://www.w3.org/2000/svg"
               viewBox="0 0 24 24" class="w-5 h-5 fill-current ml-0.5">
            <path d="M8 5v14l11-7z" />
          </svg>
        </button>

        <button
          @click="player.next()"
          class="p-2 text-muted active:text-app active:scale-95 transition-all"
          aria-label="Next"
        >
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="w-6 h-6 fill-current">
            <path d="M16 6h2v12h-2zM6 18l8.5-6L6 6z" />
          </svg>
        </button>

        <div class="flex-1 flex items-center gap-2 min-w-0">
          <span class="text-[10px] text-muted tabular shrink-0">{{ fmt(displayPosition) }}</span>
          <input
            type="range"
            min="0"
            :max="player.duration || 0"
            step="0.1"
            :value="displayPosition"
            @input="onSeekInput"
            @change="onSeekCommit"
            class="flex-1 min-w-0"
            aria-label="Seek"
          />
          <span class="text-[10px] text-muted tabular shrink-0">{{ fmt(player.duration) }}</span>
        </div>
      </div>
    </div>
  </div>
</template>
