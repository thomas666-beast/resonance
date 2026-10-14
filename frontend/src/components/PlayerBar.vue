<script setup lang="ts">
import { computed, ref } from 'vue'
import { usePlayerStore } from '@/stores/player'
import AlbumCover from './AlbumCover.vue'

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
           px-6 py-3 flex items-center gap-4 shadow-2xl z-30 text-app"
  >
    <div class="flex items-center gap-3 min-w-0 flex-1">
      <AlbumCover
        v-if="player.current.album_id"
        :album-id="player.current.album_id"
        size="sm"
      />
      <div class="min-w-0">
        <div class="text-sm font-medium truncate">{{ player.current.title }}</div>
        <div class="text-xs text-muted truncate">
          {{ player.current.artist_name ?? '—' }}
          <span v-if="player.current.album_title"> · {{ player.current.album_title }}</span>
        </div>
      </div>
    </div>

    <div class="flex items-center gap-2">
      <button
        @click="player.prev()"
        class="px-2 py-1 hover-surface rounded transition-colors"
        aria-label="Previous"
      >⏮</button>
      <button
        @click="player.toggle()"
        class="px-3 py-1 bg-accent text-white rounded-full hover:opacity-90
               transition-opacity"
        :aria-label="player.playing ? 'Pause' : 'Play'"
      >
        {{ player.playing ? '❚❚' : '▶' }}
      </button>
      <button
        @click="player.next()"
        class="px-2 py-1 hover-surface rounded transition-colors"
        aria-label="Next"
      >⏭</button>
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
</template>
